# frozen_string_literal: true

require "tzinfo"

module OverlapBoard
  TEAM = [
    ["Manila", "Asia/Manila"],
    ["Bangalore", "Asia/Kolkata"],
    ["Nairobi", "Africa/Nairobi"],
    ["Berlin", "Europe/Berlin"],
    ["Accra", "Africa/Accra"],
    ["Sao Paulo", "America/Sao_Paulo"],
    ["Toronto", "America/Toronto"]
  ].freeze


  WORK_START = 9 * 60
  WORK_END = 17 * 60

  module_function

  def utc_offset_minutes(zone, time)
    TZInfo::Timezone.get(zone).observed_utc_offset(time) / 60
  end

  def working_hours_utc(city, zone, time)
    offset = utc_offset_minutes(zone, time)
    { city: city, start: WORK_START - offset, finish: WORK_END - offset }
  end

  def format_minutes(total)
    minutes = total % 1440
    format("%02d:%02d", minutes / 60, minutes % 60)
  end

  def best_window(hours)
    edges = hours.flat_map { |h| [h[:start], h[:finish]] }.uniq.sort
    best = { start: 0, finish: 0, online: [] }
    edges.each_cons(2) do |from, to|
      online = hours.select { |h| h[:start] <= from && h[:finish] >= to }.map { |h| h[:city] }
      best = { start: from, finish: to, online: online } if online.size > best[:online].size
    end
    best
  end

  def render(time)
    hours = TEAM.map { |city, zone| working_hours_utc(city, zone, time) }
    local = "#{format_minutes(WORK_START)}-#{format_minutes(WORK_END)}"
    rows = hours.map do |h|
      "<tr><td>#{h[:city]}</td><td>#{local}</td><td>#{format_minutes(h[:start])}-#{format_minutes(h[:finish])}</td></tr>"
    end
    best = best_window(hours)

    <<~HTML
      <!doctype html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Overlap Board</title>
        <style>
          body { font-family: system-ui, sans-serif; margin: 0; padding: 2rem; background: #f6f7f9; color: #1f2328; }
          main, footer { max-width: 720px; margin: 0 auto; }
          table { width: 100%; border-collapse: collapse; background: #ffffff; }
          th, td { text-align: left; padding: 0.5rem 0.75rem; border-bottom: 1px solid #d0d7de; }
          .best-window { padding: 0.75rem; background: #ffffff; border: 1px solid #d0d7de; }
          footer { margin-top: 2rem; font-size: 0.85rem; color: #59636e; }
        </style>
      </head>
      <body>
        <main>
          <h1>Overlap Board</h1>
          <p>When is everyone on the team online? Working hours are 09:00-17:00 local time in every city.</p>
          <table>
            <thead><tr><th>City</th><th>Working hours (local)</th><th>Working hours (UTC)</th></tr></thead>
            <tbody>#{rows.join}</tbody>
          </table>
          <h2>Best window today (UTC)</h2>
          <p class="best-window">#{format_minutes(best[:start])}-#{format_minutes(best[:finish])}: #{best[:online].join(", ")} (#{best[:online].size} of #{TEAM.size} cities)</p>
        </main>
        <footer>Maintaned by the platform team.</footer>
      </body>
      </html>
    HTML
  end
end

Handler = proc do |_request, response|
  response.status = 200
  response["Content-Type"] = "text/html; charset=utf-8"
  response.body = OverlapBoard.render(Time.now.utc)
end
