defmodule Calex.DecodingTest do
  use ExUnit.Case

  require Logger

  test "decodes dates with time zones" do
    data =
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

    assert Calex.decode!(data) == [
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
                     dtstart: {"20210728T140000", [{:tzid, "America/Winnipeg"}]},
                     dtend: {"20210728T151500", [{:tzid, "America/Winnipeg"}]},
                     x_apple_travel_advisory_behavior: {"AUTOMATIC", []},
                     transp: {"OPAQUE", []}
                   ]
                 ]
               ]
             ]
           ]
  end

  test "handle Apple structured location field" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-ADDRESS="500 Nicollet St, Minneapol
       is, MN, United Stat";X-APPLE-MAPKIT-HANDLE=CAEStwIIrk0QnsWIkObE3qLyARoS CVS
       PNLitEkpAEUGK8OV0pVrAIpoBCgZDYW5hZGESAkNBGgxTYXNrYXRjaGV3YW4iAlNLKg9EaXZpc2
       lvbiBOby4gMTEyCVNhc2thdG9vbjoHUzdOIDNQOUIMRm9yZXN0IEdyb3ZlUgpXZWJzdGVyIFN0W
       gM1MDJiDjUwMiBXZWJzdGVyIFN0igEWVW5pdmVyc2l0eSBIZWlnaHRzIFNEQYoBDEZvcmVzdCBH
       cm92ZSodRm9yZXN0IEdyb3ZlIENvbW11bml0eSBDaHVyY2gyDjUwMiBXZWJzdGVyIFN0MhRTYXN
       rYXRvb24gU0sgUzdOIDNQOTIGQ2FuYWRhOC9aJwolCJ7FiJDmxN6i8gESEglUjzS4rRJKQBFBiv
       DldKVawBiuTZADAQ==;X-APPLE-RADIUS=123.4774275404302;X-APPLE-REFERENCEFRAME=
       1;X-TITLE=The Wedge:geo:42.145927,-100.585260
      END:VEVENT
      END:VCALENDAR
      """)

    decoded = [
      vcalendar: [
        [
          vevent: [
            [
              x_apple_structured_location:
                {"geo:42.145927,-100.585260",
                 [
                   value: "URI",
                   x_address: "\"500 Nicollet St, Minneapolis, MN, United Stat\"",
                   x_apple_mapkit_handle:
                     "CAEStwIIrk0QnsWIkObE3qLyARoS CVSPNLitEkpAEUGK8OV0pVrAIpoBCgZDYW5hZGESAkNBGgxTYXNrYXRjaGV3YW4iAlNLKg9EaXZpc2lvbiBOby4gMTEyCVNhc2thdG9vbjoHUzdOIDNQOUIMRm9yZXN0IEdyb3ZlUgpXZWJzdGVyIFN0WgM1MDJiDjUwMiBXZWJzdGVyIFN0igEWVW5pdmVyc2l0eSBIZWlnaHRzIFNEQYoBDEZvcmVzdCBHcm92ZSodRm9yZXN0IEdyb3ZlIENvbW11bml0eSBDaHVyY2gyDjUwMiBXZWJzdGVyIFN0MhRTYXNrYXRvb24gU0sgUzdOIDNQOTIGQ2FuYWRhOC9aJwolCJ7FiJDmxN6i8gESEglUjzS4rRJKQBFBivDldKVawBiuTZADAQ==",
                   x_apple_radius: "123.4774275404302",
                   x_apple_referenceframe: "1",
                   x_title: "The Wedge"
                 ]}
            ]
          ]
        ]
      ]
    ]

    assert Calex.decode!(data) == decoded
    assert Calex.encode!(decoded) == data
  end

  defp crlf(string) do
    string
    |> String.split("\n")
    |> Enum.join("\r\n")
  end
end
