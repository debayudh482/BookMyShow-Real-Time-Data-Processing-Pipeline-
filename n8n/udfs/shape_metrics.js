const row = $json;
const n = (v) => Number(v ?? 0);
const rup = (v) => `₹${Number(v).toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;

// Compute derived insights
const categories = [
  { name: 'Music',  value: n(row.music_revenue) },
  { name: 'Cinema', value: n(row.cinema_revenue) },
  { name: 'Sports', value: n(row.sports_revenue) },
].sort((a, b) => b.value - a.value);

const topCategory = categories[0].name;
const topPlatform =
  n(row.mobile_bookings) >= n(row.website_bookings)
    ? `Mobile App (${((n(row.mobile_bookings) / (n(row.mobile_bookings)+n(row.website_bookings)))*100).toFixed(0)}%)`
    : `Website (${((n(row.website_bookings) / (n(row.mobile_bookings)+n(row.website_bookings)))*100).toFixed(0)}%)`;

return {
  period: row.period || 'Last 7 Days',
  generated_at: new Date().toLocaleString('en-IN'),
  metrics: {
    total_revenue: rup(row.total_revenue),
    total_transactions: n(row.total_transactions),
    avg_transaction_value: rup(row.avg_transaction_value),
    unique_customers: n(row.unique_customers),
    success_rate_pct: `${Number(row.success_rate_pct).toFixed(1)}%`,
    top_city: row.top_city,
    anomalies: n(row.anomaly_count),
    avg_processing_time_ms: n(row.avg_processing_time_ms),
  },
  highlights: {
    top_category: `${topCategory} (${rup(categories[0].value)})`,
    top_platform: topPlatform
  }
};