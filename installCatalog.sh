#!/bin/bash
#
# use the command line interface to install standard actions deployed
# automatically
#
# To run this command
# ./installCatalog.sh <authkey> <edgehost> <dburl> <dbprefix> <apihost> <workers>

set -e
set -x

: ${OPENWHISK_HOME:?"OPENWHISK_HOME must be set and non-empty"}
WSK_CLI="$OPENWHISK_HOME/bin/wsk"

if [ $# -eq 0 ]
then
echo "Usage: ./installCatalog.sh <authkey> <edgehost> <dburl> <dbprefix> <apihost> <workers>"
fi

AUTH="$1"
EDGEHOST="$2"
DB_URL="$3"
DB_NAME="${4}cloudanttrigger"
APIHOST="$5"
WORKERS="$6"

# If the auth key file exists, read the key in the file. Otherwise, take the
# first argument as the key itself.
if [ -f "$AUTH" ]; then
    AUTH=`cat $AUTH`
fi

# Make sure that the EDGEHOST is not empty.
: ${EDGEHOST:?"EDGEHOST must be set and non-empty"}

# Make sure that the DB_URL is not empty.
: ${DB_URL:?"DB_URL must be set and non-empty"}

# Make sure that the DB_NAME is not empty.
: ${DB_NAME:?"DB_NAME must be set and non-empty"}

# Make sure that the APIHOST is not empty.
: ${APIHOST:?"APIHOST must be set and non-empty"}

PACKAGE_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export WSK_CONFIG_FILE= # override local property file to avoid namespace clashes

echo Installing Cloudant package.

$WSK_CLI -i --apihost "$EDGEHOST" package update --auth "$AUTH"  --shared yes cloudant \
    -a description "Cloudant database service" \
    -a parameters '[ {"name":"bluemixServiceName", "required":false, "bindTime":true}, {"name":"username", "required":true, "bindTime":true, "description": "Your Cloudant username"}, {"name":"password", "required":true, "type":"password", "bindTime":true, "description": "Your Cloudant password"}, {"name":"host", "required":true, "bindTime":true, "description": "This is usually your username.cloudant.com"}, {"name":"dbname", "required":false, "description": "The name of your Cloudant database"}, {"name":"overwrite", "required":false, "type": "boolean"} ]' \
    -p bluemixServiceName 'cloudantNoSQLDB' \
    -p host '' \
    -p username '' \
    -p password '' \
    -p dbname '' \
    -p apihost "$APIHOST"

if [ -n "$WORKERS" ];
then
    $WSK_CLI -i --apihost "$EDGEHOST" package update --auth "$AUTH" --shared no cloudantWeb \
        -p DB_URL "$DB_URL" \
        -p DB_NAME "$DB_NAME" \
        -p apihost "$APIHOST" \
        -p workers "$WORKERS"
else
    $WSK_CLI -i --apihost "$EDGEHOST" package update --auth "$AUTH" --shared no cloudantWeb \
        -p DB_URL "$DB_URL" \
        -p DB_NAME "$DB_NAME" \
        -p apihost "$APIHOST"
fi

# Cloudant feed action

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/changes "$PACKAGE_HOME/actions/changes.js" \
    -t 90000 \
    -a feed true \
    -a description 'Database change feed' \
    -a parameters '[ {"name":"dbname", "required":true, "updatable":false}, {"name": "filter", "required":false, "updatable":true, "type": "string", "description": "The name of your Cloudant database filter"}, {"name": "query_params", "required":false, "updatable":true, "description": "JSON Object containing query parameters that are passed to the filter"} ]' \
    -a sampleInput '{ "dbname": "mydb", "filter": "mailbox/by_status", "query_params": {"status": "new"} }'

# Cloudant web feed action

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudantWeb/changesWebAction "$PACKAGE_HOME/actions/changesWebAction.js" \
    -a description 'Create/Delete a trigger in cloudant provider Database' \
    --web true

# Cloudant account actions

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/create-database \
    "$PACKAGE_HOME/actions/account-actions/create-database.js" \
    -a description 'Create Cloudant database' \
    -a parameters '[ {"name":"dbname", "required":true} ]'

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/read-database \
    "$PACKAGE_HOME/actions/account-actions/read-database.js" \
    -a description 'Read Cloudant database' \
    -a parameters '[ {"name":"dbname", "required":true} ]'

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/delete-database \
    "$PACKAGE_HOME/actions/account-actions/delete-database.js" \
    -a description 'Delete Cloudant database' \
    -a parameters '[ {"name":"dbname", "required":true} ]'

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/list-all-databases \
    "$PACKAGE_HOME/actions/account-actions/list-all-databases.js" \
    -a description 'List all Cloudant databases'

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/read-updates-feed \
    "$PACKAGE_HOME/actions/account-actions/read-updates-feed.js" \
    -a description 'Read updates feed from Cloudant account (non-continuous)' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"params", "required":false} ]'

# Cloudant database actions

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/create-document \
    "$PACKAGE_HOME/actions/database-actions/create-document.js" \
    -a description 'Create document in database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"doc", "required":true, "description": "The JSON document to insert"}, {"name":"params", "required":false} ]' \

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/read \
    "$PACKAGE_HOME/actions/database-actions/read-document.js" \
    -a description 'Read document from database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"id", "required":true, "description": "The Cloudant document id to fetch"}, {"name":"params", "required":false}]' \
    -p id ''

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/read-document \
    "$PACKAGE_HOME/actions/database-actions/read-document.js" \
    -a description 'Read document from database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"docid", "required":true, "description": "The Cloudant document id to fetch"}, {"name":"params", "required":false}]' \
    -p docid ''

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/write \
    "$PACKAGE_HOME/actions/database-actions/write-document.js" \
    -a description 'Write document in database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"doc", "required":true} ]' \
    -p doc '{}'

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/update-document \
    "$PACKAGE_HOME/actions/database-actions/update-document.js" \
    -a description 'Update document in database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"doc", "required":true}, {"name":"params", "required":false} ]' \
    -p doc '{}'

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/delete-document \
    "$PACKAGE_HOME/actions/database-actions/delete-document.js" \
    -a description 'Delete document from database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"docid", "required":true, "description": "The Cloudant document id to delete"},  {"name":"docrev", "required":true, "description": "The document revision number"} ]' \
    -p docid '' \
    -p docrev ''

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/list-documents \
    "$PACKAGE_HOME/actions/database-actions/list-documents.js" \
    -a description 'List all docs from database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"params", "required":false} ]'

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/list-design-documents \
    "$PACKAGE_HOME/actions/database-actions/list-design-documents.js" \
    -a description 'List design documents from database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"includedocs", "required":false} ]' \

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/create-query-index \
    "$PACKAGE_HOME/actions/database-actions/create-query-index.js" \
    -a description 'Create a Cloudant Query index into database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"index", "required":true} ]' \
    -p index ''

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/list-query-indexes \
    "$PACKAGE_HOME/actions/database-actions/list-query-indexes.js" \
    -a description 'List Cloudant Query indexes from database' \
    -a parameters '[ {"name":"dbname", "required":true} ]' \

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/exec-query-find \
    "$PACKAGE_HOME/actions/database-actions/exec-query-find.js" \
    -a description 'Execute query against Cloudant Query index' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"query", "required":true} ]' \
    -p query ''

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/exec-query-search \
    "$PACKAGE_HOME/actions/database-actions/exec-query-search.js" \
    -a description 'Execute query against Cloudant search' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"docid", "required":true}, {"name":"indexname", "required":true}, {"name":"search", "required":true} ]' \
    -p docid '' \
    -p indexname '' \
    -p search ''

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/exec-query-view \
    "$PACKAGE_HOME/actions/database-actions/exec-query-view.js" \
    -a description 'Call view in design document from database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"docid", "required":true}, {"name":"viewname", "required":true}, {"name":"params", "required":false} ]' \
    -p docid '' \
    -p viewname ''

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/manage-bulk-documents \
    "$PACKAGE_HOME/actions/database-actions/manage-bulk-documents.js" \
    -a description 'Create, Update, and Delete documents in bulk' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"docs", "required":true}, {"name":"params", "required":false} ]' \
    -p docs '{}'

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/delete-view \
    "$PACKAGE_HOME/actions/database-actions/delete-view.js" \
    -a description 'Delete view from design document' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"docid", "required":true}, {"name":"viewname", "required":true}, {"name":"params", "required":false} ]' \
    -p docid '' \
    -p viewname ''

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/delete-query-index \
    "$PACKAGE_HOME/actions/database-actions/delete-query-index.js" \
    -a description 'Delete index from design document' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"docid", "required":true}, {"name":"indexname", "required":true}, {"name":"params", "required":false} ]' \
    -p docid '' \
    -p indexname ''

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/read-changes-feed \
    "$PACKAGE_HOME/actions/database-actions/read-changes-feed.js" \
    -a description 'Read Cloudant database changes feed (non-continuous)' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"params", "required":false} ]'

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/create-attachment \
    "$PACKAGE_HOME/actions/database-actions/create-update-attachment.js" \
    -a description 'Create document attachment in database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"docid", "required":true}, {"name":"docrev", "required":true}, {"name":"attachment", "required":true}, {"name":"attachmentname", "required":true}, {"name":"contenttype", "required":true}, {"name":"params", "required":false} ]' \
    -p docid '' \
    -p docrev '' \
    -p attachment '{}' \
    -p attachmentname '' \
    -p contenttype ''

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/read-attachment \
    "$PACKAGE_HOME/actions/database-actions/read-attachment.js" \
    -a description 'Read document attachment from database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"docid", "required":true}, {"name":"attachmentname", "required":true}, {"name":"params", "required":false} ]' \
    -p docid '' \
    -p attachmentname ''

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/update-attachment \
    "$PACKAGE_HOME/actions/database-actions/create-update-attachment.js" \
    -a description 'Update document attachment in database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"docid", "required":true}, {"name":"docrev", "required":true}, {"name":"attachment", "required":true}, {"name":"attachmentname", "required":true}, {"name":"contenttype", "required":true}, {"name":"params", "required":false} ]' \
    -p docid '' \
    -p docrev '' \
    -p attachment '{}' \
    -p attachmentname '' \
    -p contenttype ''

$WSK_CLI -i --apihost "$EDGEHOST" action update --kind nodejs:6 --auth "$AUTH" cloudant/delete-attachment \
    "$PACKAGE_HOME/actions/database-actions/delete-attachment.js" \
    -a description 'Delete document attachment from database' \
    -a parameters '[ {"name":"dbname", "required":true}, {"name":"docid", "required":true}, {"name":"docrev", "required":true}, {"name":"attachmentname", "required":true}, {"name":"params", "required":false} ]' \
    -p docid '' \
    -p docrev '' \
    -p attachmentname ''