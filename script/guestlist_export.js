// Guestlist organizer export for the members site's class numbers.
//
// Run it in the browser, signed in to guestlist.co as the lab's organizer
// account: open https://guestlist.co/manage/events, open the developer
// console (Cmd+Option+J in Chrome), paste this whole file and press Enter.
// It reads every event the account has, with ticket counts, check-ins, the
// ticket types and what guestlist collected, then saves
// guestlist-export-YYYY-MM-DD.json to your Downloads. It takes a few
// minutes for about 700 events; keep the tab in front so the browser does
// not slow it down.
//
// It reads no attendee names, emails or orders. Load the file with
// script/ticketed_events.rb (docs/analytics.md).
(async () => {
  const ACCOUNT_ID = 4662 // HeatSync Labs' guestlist account (profile 5662)
  const WORKERS = 4
  const keep = ["id", "name", "start", "stop", "published_at", "profile_id", "max_tickets", "tickets_sold",
                "complete_tickets_count", "check_ins_count", "disable_ticket_sales", "event_time_ids"]
  const get = async (path) => {
    for (let attempt = 1; attempt <= 4; attempt++) {
      const response = await fetch(path, { headers: { Accept: "application/json" } })
      if (response.ok) return response.json()
      if (response.status === 401) throw new Error("Not signed in to guestlist as the organizer")
      await new Promise((resolve) => setTimeout(resolve, 1500 * attempt))
    }
    throw new Error("guestlist did not answer " + path)
  }

  const list = await get(`/api/events?account_id=${ACCOUNT_ID}`)
  const events = list.events.map((event) => Object.fromEntries(keep.map((key) => [key, event[key]])))
  console.log(`Reading ${events.length} events...`)
  let next = 0, done = 0
  const worker = async () => {
    while (next < events.length) {
      const event = events[next++]
      const sales = await get(`/api/sales_chart_data?event_id=${event.id}`)
      const types = await get(`/api/ticket_types?event_id=${event.id}`)
      event.dollars = sales.sales_chart_data.dollars_collected
      event.ticket_types = types.ticket_types.map(({ name, price, tickets_sold, complete_tickets_count, check_ins_count }) =>
        ({ name, price, tickets_sold, complete_tickets_count, check_ins_count }))
      if (++done % 50 === 0) console.log(`${done} of ${events.length}`)
    }
  }
  await Promise.all(Array.from({ length: WORKERS }, worker))

  const exportedAt = new Date().toISOString()
  const file = new Blob([JSON.stringify({ exported_at: exportedAt, account_id: ACCOUNT_ID, events, event_times: list.event_times })],
                        { type: "application/json" })
  const link = Object.assign(document.createElement("a"), { href: URL.createObjectURL(file), download: `guestlist-export-${exportedAt.slice(0, 10)}.json` })
  document.body.append(link); link.click(); link.remove()
  console.log(`Saved ${events.length} events to guestlist-export-${exportedAt.slice(0, 10)}.json`)
})()
