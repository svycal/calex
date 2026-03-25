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

  test "decodes ambiguous timestamps" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      DTSTAMP;TZID=America/New_York:20251102T010000
      END:VEVENT
      END:VCALENDAR
      """)

    {:ambiguous, first, _second} = DateTime.new(~D[2025-11-02], ~T[01:00:00], "America/New_York")

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     dtstamp: {first, [tzid: "America/New_York"]}
                   ]
                 ]
               ]
             ]
           ]
  end

  test "decodes gap timestamps" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      DTSTAMP;TZID=Europe/Copenhagen:20190331T023000
      END:VEVENT
      END:VCALENDAR
      """)

    {:gap, _first, second} = DateTime.new(~D[2019-03-31], ~T[02:30:00], "Europe/Copenhagen")

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     dtstamp: {second, [tzid: "Europe/Copenhagen"]}
                   ]
                 ]
               ]
             ]
           ]
  end

  test "decodes naive/floating datetimes" do
    data =
      crlf("""
      BEGIN:DAYLIGHT
      DTSTART:20241103T010000
      END:DAYLIGHT
      """)

    assert Calex.decode!(data) == [
             daylight: [
               [
                 dtstart: {~N[2024-11-03 01:00:00], []}
               ]
             ]
           ]

    assert Calex.encode!(Calex.decode!(data)) == data
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
                       {Duration.from_iso8601!("PT30M"), [value: "DURATION"]}
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
       1;X-TITLE=The Wedge:geo:42.145927\\,-100.585260
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
                   x_address: "500 Nicollet St, Minneapolis, MN, United Stat",
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
      "BEGIN:VCALENDAR\r\nX-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-ADDRESS=9999 Harmington drive\\\\nM\r\n yrtle Beach SC 29579\\\\nUnited States;X-APPLE-ABUID=\"Aderam Boere’s Home\"\r\n ::;X-APPLE-MAPKIT-HANDLE=CAESiwII2TIaEgkND6uJT9tAQBF6MM6Ey7xTwCJzCg1Vbml\r\n 0ZWQgU3RhdGVzEgJVUxoOU291dGggQ2Fyb2xpbmEiAlNDKgxIb3JyeSBDb3VudHkyDE15cnR\r\n sZSBCZWFjaDoFMjk1NzlSDUZhcm1pbmd0b24gUGxaBDM2MDliEjM2MDkgRmFybWluZ3RvbiB\r\n QbCoSMzYwOSBGYXJtaW5ndG9uIFBsMhIzNjA5IEZhcm1pbmd0b24gUGwyF015cnRsZSBCZWF\r\n jaCwgU0MgIDI5NTc5Mg1Vbml0ZWQgU3RhdGVzODlAAFABWicKJRISCQ0Pq4lP20BAEXowzoT\r\n LvFPAGNkyILKqy+yG3YCw7wGQAwE=;X-APPLE-RADIUS=70.58730101326454;X-APPLE-R\r\n EFERENCEFRAME=1;X-TITLE=9999 Harmington drive\nMyrtle Beach SC 29579\nUnited States:geo:99.999999,-99.999999\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

    exception =
      try do
        Calex.decode!(data)
      rescue
        e in [Calex.DecodeError] -> e
      end

    assert exception.message ==
             "property key invalid: \"Myrtle Beach SC 29579\" (reason: invalid_characters)"
  end

  test "fails on line with no property key" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      :text
      END:VEVENT
      END:VCALENDAR
      """)

    assert_raise(Calex.DecodeError, "property key missing or blank line", fn ->
      Calex.decode!(data)
    end)
  end

  test "fails on blank line" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT

      END:VEVENT
      END:VCALENDAR
      """)

    assert_raise(Calex.DecodeError, "property key missing or blank line", fn ->
      Calex.decode!(data)
    end)
  end

  test "decodes empty values" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      LOCATION:
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     location: {"", []}
                   ]
                 ]
               ]
             ]
           ]
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
                     duration: {Duration.from_iso8601!("PT1H"), []}
                   ]
                 ]
               ]
             ]
           ]
  end

  test "bad DURATION property value is just returned as-is" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      DURATION:LONGTIME
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     duration: {"LONGTIME", []}
                   ]
                 ]
               ]
             ]
           ]
  end

  test "bad DURATION value is just returned as-is" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      X-APPLE-TRAVEL-DURATION;VALUE=DURATION:LONGTIME
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     x_apple_travel_duration: {"LONGTIME", [value: "DURATION"]}
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

  test "handles invalid time zones" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      DTSTART;TZID=Romance Standard Time:20240404T091500
      DTEND;TZID=Romance Standard Time:20240404T104500
      END:VEVENT
      END:VCALENDAR
      """)

    assert_raise Calex.InvalidTimeZoneError, fn ->
      Calex.decode!(data)
    end
  end

  test "escaped semicolon and colon in param values" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      ORGANIZER;CN=Dwayne 'The Rock' Johnson;SENT-BY="mailto:person@example.com";
       X-COMMA="1,2,3";X-SEMICOLON="1;2;3":mailto:organizer@example.com
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     organizer: {
                       "mailto:organizer@example.com",
                       [
                         cn: "Dwayne 'The Rock' Johnson",
                         sent_by: "mailto:person@example.com",
                         x_comma: "1,2,3",
                         x_semicolon: "1;2;3"
                       ]
                     }
                   ]
                 ]
               ]
             ]
           ]
  end

  test "escaped characters in property value" do
    # note the ~S used here to disable escaping
    data =
      crlf(~S"""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      DESCRIPTION:text escaping \\ \; \, \N \n \\n end
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     description: {
                       "text escaping \\ ; , \n \n \\n end",
                       []
                     }
                   ]
                 ]
               ]
             ]
           ]
  end

  test "accumulate blocks of the same key" do
    data =
      crlf("""
      BEGIN:VCALENDAR
      BEGIN:VEVENT
      SUBJECT:event 1
      END:VEVENT
      BEGIN:VEVENT
      SUBJECT:event 2
      END:VEVENT
      END:VCALENDAR
      """)

    assert Calex.decode!(data) == [
             vcalendar: [
               [
                 vevent: [
                   [
                     subject: {"event 1", []}
                   ],
                   [
                     subject: {"event 2", []}
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
