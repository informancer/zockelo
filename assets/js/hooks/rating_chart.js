// RatingChart hook — renders a Chart.js line chart of rating history.
// data-points should be a JSON array of {date, rating} objects.
const RatingChart = {
  mounted() {
    this.renderChart()
  },
  updated() {
    if (this.chart) this.chart.destroy()
    this.renderChart()
  },
  destroyed() {
    if (this.chart) this.chart.destroy()
  },
  renderChart() {
    const raw = this.el.dataset.points
    let points = []
    try { points = JSON.parse(raw || "[]") } catch (_) {}

    if (points.length === 0) {
      this.el.innerHTML = '<p class="text-center text-gray-400 text-sm pt-16">No rating history yet.</p>'
      return
    }

    const canvas = document.createElement("canvas")
    canvas.style.width = "100%"
    canvas.style.height = "100%"
    this.el.innerHTML = ""
    this.el.appendChild(canvas)

    this.chart = new window.Chart(canvas, {
      type: "line",
      data: {
        labels: points.map(p => p.date),
        datasets: [{
          label: "Rating",
          data: points.map(p => p.rating),
          borderColor: "#2563eb",
          backgroundColor: "rgba(37,99,235,0.1)",
          tension: 0.3,
          pointRadius: 4,
          fill: true
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              title: (items) => items[0].label,
              label: (item) => `Rating: ${item.raw}`
            }
          }
        },
        scales: {
          y: { beginAtZero: false }
        }
      }
    })
  }
}

export default RatingChart
