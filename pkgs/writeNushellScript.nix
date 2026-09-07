{
  writeScript,
  nushell,
}:

name: text:
writeScript name ''
  #!${nushell}/bin/nu
  ${text}
''
