# Hotel Booking Platform — DevOps Assessment

Terraform design for `Internet -> ALB -> ECS/Fargate -> RDS`, plus a local MySQL setup with backup/restore and an optimized query. Actual AWS deployment is not required or performed.

## Repository structure

```
.
├── .github/workflows/terraform-plan.yml   # plan-only CI on pull requests
├── infra/
│   ├── modules/{network,ecs,rds}          # reusable Terraform modules
│   └── envs/{dev,prod}                    # environment-specific config
├── database/migrations/                   # schema + seed data (run in order)
├── scripts/{backup.sh,restore.sh}
├── docker-compose.yml
├── .env.example
└── .gitignore
```

## Architecture

Internet -> ALB (public subnets) -> ECS/Fargate service running `nginx:alpine` (private subnets) -> RDS MySQL (private subnets).

- ALB security group: allows inbound 80 from the internet.
- ECS security group: allows inbound 80 only from the ALB security group.
- RDS security group: allows inbound 3306 only from the ECS security group.
- RDS is `publicly_accessible = false` and sits only in private subnets.

## Terraform

```bash
cd infra/envs/dev        # or infra/envs/prod
terraform fmt -check -recursive ../../
terraform init -backend=false     # add -backend=false only when testing without an S3 bucket
terraform validate
terraform plan -refresh=false
```

`dev` and `prod` call the same three modules (`network`, `ecs`, `rds`) with different `terraform.tfvars`:

| Setting | dev | prod |
|---|---|---|
| ECS cpu/memory | 256/512 | 512/1024 |
| ECS desired count | 1 | 2 |
| RDS instance class | db.t3.micro | db.t3.medium |
| RDS backup retention | 1 day | 7 days |
| RDS deletion protection | false | true |

Each environment has its own `backend.tf` with a separate state key (`dev/terraform.tfstate`, `prod/terraform.tfstate`) against the placeholder bucket `YOUR_TERRAFORM_STATE_BUCKET`. `db_password` is a placeholder variable (`YOUR_DB_PASSWORD`) — no real credentials are stored.

The GitHub Actions workflow (`.github/workflows/terraform-plan.yml`) runs `fmt`, `init -backend=false`, `validate` and `plan -refresh=false` for both environments on every pull request. It is plan-only: no apply, no AWS credentials required.

## Local database

```bash
cp .env.example .env      # fill in real values for local use
docker compose up -d
```

The compose file mounts `database/migrations/` into MySQL's `docker-entrypoint-initdb.d`, so `001_create_tables.sql` and `002_seed_data.sql` run automatically the first time the container initializes its data volume (i.e. on a fresh `db_data` volume). To reload from scratch:

```bash
docker compose down -v
docker compose up -d
```

Verify the seed loaded:

```bash
docker exec -it hotel-booking-mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" hotel_booking_db \
  -e "SELECT COUNT(*) FROM hotel_bookings; SELECT COUNT(*) FROM booking_events;"
```

Expected: 100 hotel bookings, 75 booking events.

## Query optimization

Target query:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL 30 DAY
GROUP BY org_id, status;
```

Index added: `INDEX idx_hotel_bookings_city_created_at (city, created_at)`.

`city` is an equality filter and `created_at` is a range filter, so putting `city` first lets MySQL jump straight to the matching rows and then scan only the last-30-days range within that city, instead of scanning the whole table. `EXPLAIN` on this dataset shows `type: range` using that index, instead of a full table scan.

## Backup and restore

```bash
./scripts/backup.sh
```

Creates a timestamped dump at `backups/backup_YYYYMMDD_HHMMSS.sql` via `mysqldump` inside the running container. Fails (non-zero exit, no partial file left behind) if the dump command fails or produces an empty file.

```bash
./scripts/restore.sh                          # restores the most recent file in backups/
./scripts/restore.sh backups/backup_<ts>.sql  # or restore a specific file
```

`restore.sh` drops and recreates `hotel_booking_db_restore` and loads the dump into that fresh database, leaving the original `hotel_booking_db` untouched.

Verify the restore:

```bash
docker exec -it hotel-booking-mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" \
  -e "SELECT COUNT(*) FROM hotel_booking_db_restore.hotel_bookings; SELECT COUNT(*) FROM hotel_booking_db_restore.booking_events;"
```

Expected: 100 hotel bookings (>=100) and 75 booking events, matching the original database.

## Requirement checklist

| Requirement | Where |
|---|---|
| VPC, public/private subnets | `infra/modules/network` |
| ALB / ECS / RDS security groups | `infra/envs/<env>/main.tf` |
| ECS cluster, task definition, service | `infra/modules/ecs` |
| RDS MySQL, private only | `infra/modules/rds` |
| dev/prod envs, same modules, different sizing | `infra/envs/dev`, `infra/envs/prod` |
| Separate backend state keys | `infra/envs/<env>/backend.tf` |
| GitHub Actions plan-only workflow | `.github/workflows/terraform-plan.yml` |
| MySQL via Docker Compose | `docker-compose.yml`, `.env.example` |
| `hotel_bookings` / `booking_events` schema | `database/migrations/001_create_tables.sql` |
| Seed: 100+ bookings, multiple cities/orgs/statuses, events | `database/migrations/002_seed_data.sql` |
| Index for the target query | `001_create_tables.sql` (explained above) |
| Backup script | `scripts/backup.sh` |
| Restore script | `scripts/restore.sh` |
