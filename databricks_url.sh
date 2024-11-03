#!/usr/bin/env bash

set +e   # required, we do our own error handling

# jdbc:databricks://adb-5159569612410553.13.azuredatabricks.net:443/default;transportMode=http;ssl=1;AuthMech=3;httpPath=/sql/1.0/warehouses/488e168bff1be1d1;

refresh_interval=$1
connection="$2"

if [ -z "${refresh_interval}" -o -z "${connection}" ]; then
  echo -en "usage: \n" \
  "\n" \
  "$0 refresh_interval connection_as_copied_from_sql_warehouse\n"
  exit 1
fi

mapfile -td \; url_fields < <(printf "%s\0" "$connection")

for uf in "${url_fields[@]}"
do
  case "${uf}" in
  jdbc:databricks:*)
    base="${uf}"
    ;;
  AuthMech=*)
    auth_mech="${uf}"
    ;;
  *)
    ;;
  esac
done
_connection="${connection/$auth_mech/AuthMech=11}"

echo "Constructing Databricks JDBC URL connection to ${base}"

# Log in to Azure CLI if required
if az account show -o jsonc >> /dev/null;
then
  echo "Already logged in to Azure";
else
  echo "Check browser to login";
  az login
  echo "Logged in to Azure";
fi

# Get token
token=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d | jq -r .accessToken);
#echo "token: ${token}"

# Construct new JDBC URL
if [[ "${_connection}" =~ ';'$ ]]; then 
  _connection=${_connection::-1}
fi
_connection="${_connection};PWD=refresh_token;Auth_Flow=2;Auth_AccessToken=${token}"
echo "${_connection}"

# Run again after refresh interval
if [ ! -z "${refresh_interval}" ]; then
  sleep ${refresh_interval}
  exec "$0" ${refresh_interval} "${connection}"
fi
