{ lib }:

{ region, streamToken, fileLogs ? [], journalLogs ? [] }:

let
  renderFileLog = idx: log: ''
    [sources.file_${toString idx}]
    type = "file"
    include = ["${log.filePath}"]
    read_from = "beginning"

    [sinks.file_${toString idx}_cloudwatch]
    type = "aws_cloudwatch_logs"
    inputs = ["file_${toString idx}"]
    group_name = "${log.logGroupName}"
    stream_name = "${log.logStreamName}-${streamToken}"
    region = "${region}"

    [sinks.file_${toString idx}_cloudwatch.encoding]
    codec = "text"
  '';

  renderJournalLog = idx: log:
    let
      matchLine =
        if log.matchField == "SYSTEMD_UNIT" then
          "include_units = [${builtins.toJSON log.matchValue}]"
        else
          "include_matches.${log.matchField} = [${builtins.toJSON log.matchValue}]";
    in
    ''
      [sources.journald_${toString idx}]
      type = "journald"
      ${matchLine}

      [sinks.journald_${toString idx}_cloudwatch]
      type = "aws_cloudwatch_logs"
      inputs = ["journald_${toString idx}"]
      group_name = "${log.logGroupName}"
      stream_name = "${log.logStreamName}-${streamToken}"
      region = "${region}"

      [sinks.journald_${toString idx}_cloudwatch.encoding]
      codec = "text"
    '';

  fileSections =
    lib.concatStringsSep "\n\n"
      (lib.imap0 renderFileLog fileLogs);

  journalSections =
    lib.concatStringsSep "\n\n"
      (lib.imap0 renderJournalLog journalLogs);

  sections =
    lib.concatStringsSep "\n\n"
      (lib.filter (section: section != "") [
        fileSections
        journalSections
      ]);
in
if sections == "" then
  "data_dir = \"/var/lib/vector\"\n"
else
  ''
data_dir = "/var/lib/vector"

${sections}
''
