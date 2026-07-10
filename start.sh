#!/bin/bash

config_injected=false

for varname in ${!langtool_*}
do
  key="${varname#'langtool_'}"
  value="${!varname}"

  if [ "$key" = "fasttextModel" ]; then
    echo "Error: fasttextModel is managed by the container and must not be overridden via langtool_fasttextModel." >&2
    exit 1
  elif [ "$key" = "fasttextBinary" ]; then
    echo "Error: fasttextBinary is managed by the container and must not be overridden via langtool_fasttextBinary." >&2
    exit 1
  fi

  config_injected=true
  echo "$key=$value" >> config.properties
done

if [ "$config_injected" = true ] ; then
  echo 'LanguageTool configuration was extended from langtool_* environment variables.'
fi

Xms=${Java_Xms:-256m}
Xmx=${Java_Xmx:-512m}
allow_origin=${LANGUAGETOOL_ALLOW_ORIGIN:-}

PRIO_ARGS=(  
  "-Xms$Xms"
  "-Xmx$Xmx"
)

if [ -f /LanguageTool/logback.xml ] ; then
  PRIO_ARGS+=("-Dlogback.configurationFile=/LanguageTool/logback.xml")
fi

LT_ARGS=(
  -cp languagetool-server.jar
  org.languagetool.server.HTTPServer
  --port 8010
  --public
  --config config.properties
)

if [ -n "$allow_origin" ] ; then
  LT_ARGS+=(--allow-origin "$allow_origin")
fi

set -x
exec java "${PRIO_ARGS[@]}" "${LT_ARGS[@]}"
