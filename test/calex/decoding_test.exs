defmodule Calex.DecodingTest do
  @moduledoc false

  use ExUnit.Case

  require Logger

  test "decodes UTC dates" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      DTSTAMP:20210601T000000Z
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     dtstamp: {~U[2021-06-01 00:00:00Z], []}
                   ]
                 ]
               ]
             ]
           ]
  end

  test "decodes non-UTC dates" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      DTSTAMP;TZID=America/Chicago:20210601T000000
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     dtstamp:
                       {DateTime.from_naive!(~N[2021-06-01 00:00:00], "America/Chicago"),
                        [tzid: "America/Chicago"]}
                   ]
                 ]
               ]
             ]
           ]
  end

  test "decodes dates" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      DTSTAMP;VALUE=DATE:20210601
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     dtstamp: {~D[2021-06-01], [value: "DATE"]}
                   ]
                 ]
               ]
             ]
           ]
  end

  test "decodes Apple travel time" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      X-APPLE-TRAVEL-DURATION;VALUE=DURATION:PT30M
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     x_apple_travel_duration:
                       {Timex.Duration.from_minutes(30), [value: "DURATION"]}
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

  test "fails on malformed newlines in X-APPLE-STRUCTURED-LOCATION" do
    # Apple does not properly encode newlines in properies on their X-APPLE-STRUCTURED-LOCATION
    # field. They are supposed be \\n instead of \n. This is not very easy for us to work around
    # since it's in a fundamentally improper format, so for now we'll just raise a special error.
    #
    # https://github.com/nextcloud/calendar/issues/3905#issuecomment-1029970769

    data =
      "BEGIN:VCALENDAR\r\nX-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-ADDRESS=3609 Farmington place\\\\nM\r\n yrtle Beach SC 29579\\\\nUnited States;X-APPLE-ABUID=\"Amanda Loehr’s Home\"\r\n ::;X-APPLE-MAPKIT-HANDLE=CAESiwII2TIaEgkND6uJT9tAQBF6MM6Ey7xTwCJzCg1Vbml\r\n 0ZWQgU3RhdGVzEgJVUxoOU291dGggQ2Fyb2xpbmEiAlNDKgxIb3JyeSBDb3VudHkyDE15cnR\r\n sZSBCZWFjaDoFMjk1NzlSDUZhcm1pbmd0b24gUGxaBDM2MDliEjM2MDkgRmFybWluZ3RvbiB\r\n QbCoSMzYwOSBGYXJtaW5ndG9uIFBsMhIzNjA5IEZhcm1pbmd0b24gUGwyF015cnRsZSBCZWF\r\n jaCwgU0MgIDI5NTc5Mg1Vbml0ZWQgU3RhdGVzODlAAFABWicKJRISCQ0Pq4lP20BAEXowzoT\r\n LvFPAGNkyILKqy+yG3YCw7wGQAwE=;X-APPLE-RADIUS=70.58730101326454;X-APPLE-R\r\n EFERENCEFRAME=1;X-TITLE=3609 Farmington place\nMyrtle Beach SC 29579\nUnited States:geo:33.713365,-78.949922\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

    exception =
      try do
        Calex.decode!(data)
      rescue
        e in [Calex.DecodeError] -> e
      end

    assert exception.message == "property has no value: [\"Myrtle Beach SC 29579\"]"
  end

  test "decodes negative GMT offset dates" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      DTSTART;TZID=GMT-0400:20210601T000000
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     dtstart: {~U[2021-06-01 04:00:00Z], [tzid: "GMT-0400"]}
                   ]
                 ]
               ]
             ]
           ]

    assert Calex.encode!(Calex.decode!(data)) ==
             crlf("""
             BEGIN:VCALENDAR
             BEGIN:VEVENT
             DTSTART:20210601T040000Z
             END:VEVENT
             END:VCALENDAR
             """)
  end

  test "decodes positive GMT offset dates" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      DTSTART;TZID=GMT+0400:20210601T000000
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     dtstart: {~U[2021-05-31 20:00:00Z], [tzid: "GMT+0400"]}
                   ]
                 ]
               ]
             ]
           ]

    assert Calex.encode!(Calex.decode!(data)) ==
             crlf("""
             BEGIN:VCALENDAR
             BEGIN:VEVENT
             DTSTART:20210531T200000Z
             END:VEVENT
             END:VCALENDAR
             """)
  end

  test "decodes the DURATION property" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      DURATION:PT1H
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     duration: {Timex.Duration.from_hours(1), []}
                   ]
                 ]
               ]
             ]
           ]
  end

  test "decodes malformed timestamps without zone info as UTC" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      DTSTAMP:20210601T000000
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     dtstamp: {~U[2021-06-01 00:00:00Z], []}
                   ]
                 ]
               ]
             ]
           ]
  end

  test "truncates very long property names" do
    long_name = 0..256 |> Enum.map_join(fn _ -> "X" end)
    truncated_long_name = 0..254 |> Enum.map_join(fn _ -> "x" end) |> String.to_atom()

    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      #{long_name}:value
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     {truncated_long_name, {"value", []}}
                   ]
                 ]
               ]
             ]
           ]
  end

  defp crlf(string) do
    string
    |> String.split("\n")
    |> Enum.join("\r\n")
  end
end
