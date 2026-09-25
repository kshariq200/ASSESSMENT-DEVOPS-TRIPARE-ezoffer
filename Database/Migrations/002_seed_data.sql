-- Seed data: 100 hotel bookings across 5 cities, 3 organizations and 4 statuses.
INSERT INTO hotel_bookings (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
WITH RECURSIVE seq (n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 100
)
SELECT
    UUID(),
    ELT(1 + (n MOD 3),
        "11111111-1111-1111-1111-111111111111",
        "22222222-2222-2222-2222-222222222222",
        "33333333-3333-3333-3333-333333333333"),
    CONCAT("hotel-", 1 + (n MOD 10)),
    ELT(1 + (n MOD 5), "delhi", "mumbai", "bengaluru", "pune", "jaipur"),
    CURDATE() - INTERVAL (n MOD 20) DAY,
    CURDATE() - INTERVAL (n MOD 20) DAY + INTERVAL 2 DAY,
    500.00 + (n * 25.50),
    ELT(1 + (n MOD 4), "confirmed", "cancelled", "pending", "completed"),
    NOW() - INTERVAL (n MOD 40) DAY
FROM seq;

-- Booking events for roughly three quarters of the bookings.
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id, CONCAT(status, "_event"), JSON_OBJECT("status", status, "amount", amount), created_at
FROM hotel_bookings
WHERE status <> "pending";
