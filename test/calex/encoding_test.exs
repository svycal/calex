defmodule Calex.EncodingTest do
  use ExUnit.Case

  test "encodes iCal keyword list" do
    data = [
      vcalendar: [
        [
          vevent: [
            [
              dtstamp: {"20210727T183739Z", []},
              summary: {"Hello World", []},
              description: {"Here are some notes!", []},
              location: {"", []},
              tzid: {"America/Winnipeg", []},
              sequence: {"0", []},
              uid: {"1C192BA5-A5FE-481F-B111-4D401208070E", []},
              created: {"20210727T183739Z", []},
              dtstart: {"20210728T140000", [tzid: "America/Winnipeg"]},
              dtend: {"20210728T151500", [tzid: "America/Winnipeg"]},
              x_apple_travel_advisory_behavior: {"AUTOMATIC", []},
              transp: {"OPAQUE", []}
            ]
          ]
        ]
      ]
    ]

    assert Calex.encode!(data) ==
             crlf("""
             BEGIN:VCALENDAR
             BEGIN:VEVENT
             DTSTAMP:20210727T183739Z
             SUMMARY:Hello World
             DESCRIPTION:Here are some notes!
             LOCATION:
             TZID:America/Winnipeg
             SEQUENCE:0
             UID:1C192BA5-A5FE-481F-B111-4D401208070E
             CREATED:20210727T183739Z
             DTSTART;TZID=America/Winnipeg:20210728T140000
             DTEND;TZID=America/Winnipeg:20210728T151500
             X-APPLE-TRAVEL-ADVISORY-BEHAVIOR:AUTOMATIC
             TRANSP:OPAQUE
             END:VEVENT
             END:VCALENDAR
             """)
  end

  defp crlf(string) do
    string
    |> String.split("\n")
    |> Enum.join("\r\n")
  end
end
