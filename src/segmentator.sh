#!/bin/bash
#
# author: Aleksey Korzun <aleksey@baublebar.com>
# version: 1.0.1    

echo "=========================================================================="
echo " Magento Data Segmentator v1.0.1                                          "
echo "=========================================================================="

help() {
    echo "Usage: -s schema [-f filename] [-e '(generic.com|specific.email@domain.com)'] [-d 7] [-l 1000] [-r 1]" 1>&2;
    exit 1;
}

while getopts ":s:f:e:d:l:r:" o; do
    case "${o}" in
        s)
            SCHEMA=${OPTARG}
            ;;
        f)
            FILENAME=${OPTARG}
            ;;
        e)
            EMAIL=${OPTARG}
            ;;
        d)
            DAYS=${OPTARG}
            ;;
        l)
            LIMIT=${OPTARG}
            ;;
        r)
            IS_RAW=${OPTARG}
            ;;
        *)
            help
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${SCHEMA}" ]; then
    help
fi

if [ -z "${EMAIL}" ] && [ -z "${DAYS}" ]; then
    help
fi

if [ -z "${FILENAME}" ]; then
    FILENAME=`date -u +"%Y%m%d%H%M"`
fi

if [ -z "${IS_RAW}" ]; then
    IS_RAW=0
fi

DUMP_CMD="mysqldump $SCHEMA --single-transaction --opt --skip-lock-tables --skip-comments"

###################
# General Data
###################

GENERAL_TABLES="
am_ogrid_order_item
am_ogrid_order_item_product
amasty_audit_log
amasty_audit_log_details
captcha_log
core_cache
core_cache_option
core_cache_tag
core_session
cron_schedule
customer_address_entity
customer_address_entity_int
customer_address_entity_text
customer_address_entity_varchar
customer_entity
customer_entity_datetime
customer_entity_decimal
customer_entity_int
customer_entity_text
customer_entity_varchar
dataflow_batch_export
dataflow_batch_import
downloadable_link_purchased
enterprise_customerbalance
enterprise_customersegment_customer
enterprise_customer_sales_flat_quote
enterprise_customer_sales_flat_quote_address
enterprise_giftregistry_entity
enterprise_logging_event
enterprise_logging_event_changes
enterprise_reminder_rule_log
enterprise_sales_creditmemo_grid_archive
enterprise_sales_invoice_grid_archive
enterprise_sales_order_grid_archive
enterprise_sales_shipment_grid_archive
enterprise_invitation
enterprise_reward
enterprise_rma
enterprise_rma_grid
index_event
index_process_event
log_customer
log_quote
log_summary
log_summary_type
log_url
log_url_info
log_visitor
log_visitor_info
log_visitor_online
newsletter_subscriber
gift_message
oauth_token
persistent_session
poll_vote
product_alert_price
product_alert_stock
rating_option_vote
report_event
report_viewed_product_index
rewards_transfer
rewards_transfer_reference
rewards_customer_index_points
rewardssocial_facebook_like
sales_billing_agreement
sales_bestsellers_aggregated_daily
sales_flat_creditmemo
sales_flat_creditmemo_grid
sales_flat_invoice
sales_flat_invoice_grid
sales_flat_invoice_comment
sales_flat_invoice_item
sales_flat_order
sales_flat_order_address
sales_flat_order_grid
sales_flat_order_item
sales_flat_order_payment
sales_flat_order_status_history
sales_flat_quote
sales_flat_quote_address
sales_flat_quote_address_item
sales_flat_quote_item
sales_flat_quote_item_option
sales_flat_quote_payment
sales_flat_quote_shipping_rate
sales_flat_shipment
sales_flat_shipment_item
sales_flat_shipment_grid
sales_flat_shipment_track
sales_order_tax
sales_payment_transaction
sales_recurring_profile
sales_recurring_profile_order
salesrule_coupon_usage
salesrule_customer
sendfriend_log
tax_order_aggregated_created
tax_order_aggregated_updated
tag_relation
wishlist"

# Create DB dump
IGN_SCH=
IGN_IGN=

for TABLE in $GENERAL_TABLES; do
    IGN_SCH="$IGN_SCH '$TABLE'"
    IGN_IGN="$IGN_IGN --ignore-table='$SCHEMA'.'$TABLE'"
done

CMD="nice -n 10 $DUMP_CMD $IGN_IGN; nice -n 10 $DUMP_CMD --no-data $IGN_SCH;"

###################
# Customer
###################

QUERY_WHERE=

if [[ $DAYS =~ ^[0-9]+$ ]]; then
    QUERY_WHERE="AND DATE_FORMAT(created_at, '%Y-%m-%d %h:%i:%s') > DATE_SUB(NOW(), INTERVAL $DAYS DAY)"
fi

if ! [[ -z "$EMAIL" ]]; then
    if [[ $DAYS =~ ^[0-9]+$ ]]; then
        QUERY_WHERE="$QUERY_WHERE OR email REGEXP '$EMAIL'";
    else
        QUERY_WHERE="$QUERY_WHERE AND email REGEXP '$EMAIL'";
    fi
fi

QUERY_WHERE=${QUERY_WHERE:4:${#QUERY_WHERE}}

QUERY_LIMIT=
if [[ $LIMIT =~ ^[0-9]+$ ]]; then
    QUERY_LIMIT=" LIMIT $LIMIT"
fi

CUSTOMER_IDS=

eval COMMAND=\$\("mysql $SCHEMA -e \"SELECT entity_id FROM customer_entity WHERE $QUERY_WHERE ORDER BY entity_id ASC $QUERY_LIMIT\""\)

for OUTPUT in $COMMAND
do
    re='^[0-9]+$'
    if ! [[ $OUTPUT =~ $re ]] ; then
       continue
    elif [[ -z "$OUTPUT" ]] ; then
       continue
    fi

    CUSTOMER_IDS="$CUSTOMER_IDS, $OUTPUT"
done

if [[ "$CUSTOMER_IDS" == "" ]]; then
    echo "Criteria did not result any results"
    exit 1
fi

echo "Working, please be patient"

CUSTOMER_IDS=${CUSTOMER_IDS:1:${#CUSTOMER_IDS}}

CUSTOMER_TABLES="
customer_entity
customer_entity_datetime
customer_entity_decimal
customer_entity_int
customer_entity_text
customer_entity_varchar
"

for TABLE in $CUSTOMER_TABLES; do
   CMD="$CMD nice -10 $DUMP_CMD --no-create-info --tables $TABLE --where='entity_id IN ($CUSTOMER_IDS)';"
done

###################
# Customer Address
###################

eval COMMAND=\$\("mysql $SCHEMA -e 'SELECT entity_id FROM customer_address_entity WHERE parent_id IN ($CUSTOMER_IDS)'"\)

CUSTOMER_ADDRESS_IDS=

for OUTPUT in $COMMAND
do
    re='^[0-9]+$'
    if ! [[ $OUTPUT =~ $re ]] ; then
       continue
    elif [[ -z "$OUTPUT" ]] ; then
        continue
    fi

    CUSTOMER_ADDRESS_IDS="$CUSTOMER_ADDRESS_IDS, $OUTPUT"
done

CUSTOMER_ADDRESS_IDS=${CUSTOMER_ADDRESS_IDS:1:${#CUSTOMER_ADDRESS_IDS}}

CUSTOMER_ADDRESS_TABLES="
customer_address_entity
customer_address_entity_text
customer_address_entity_int
customer_address_entity_varchar
"

for TABLE in $CUSTOMER_ADDRESS_TABLES; do
   CMD="$CMD nice -10 $DUMP_CMD --no-create-info --tables $TABLE --where='entity_id IN ($CUSTOMER_ADDRESS_IDS)';"
done

###################
# Customer Order
###################

eval COMMAND=\$\("mysql $SCHEMA -e 'SELECT entity_id FROM sales_flat_order WHERE customer_id IN ($CUSTOMER_IDS)'"\)

CUSTOMER_ORDER_IDS=

for OUTPUT in $COMMAND
do
    re='^[0-9]+$'
    if ! [[ $OUTPUT =~ $re ]] ; then
       continue
    elif [[ -z "$OUTPUT" ]] ; then
       continue
    fi

    CUSTOMER_ORDER_IDS="$CUSTOMER_ORDER_IDS, $OUTPUT"
done

CUSTOMER_ORDER_IDS=${CUSTOMER_ORDER_IDS:1:${#CUSTOMER_ORDER_IDS}}

CUSTOMER_ORDER_METADATA_TABLES="
enterprise_sales_order_grid_archive
sales_flat_order
sales_flat_order_grid
sales_flat_shipment_grid
sales_flat_shipment_track
"

for TABLE in $CUSTOMER_ORDER_METADATA_TABLES; do
    CMD="$CMD nice -10 $DUMP_CMD --no-create-info --tables $TABLE --where='entity_id IN ($CUSTOMER_ORDER_IDS)';"
done

CUSTOMER_ORDER_METADATA_TABLES="
sales_order_tax
sales_flat_order_item
sales_flat_invoice_grid
sales_flat_creditmemo
sales_flat_creditmemo_grid
sales_recurring_profile_order
enterprise_sales_invoice_grid_archive
enterprise_sales_creditmemo_grid_archive
enterprise_sales_shipment_grid_archive
"

for TABLE in $CUSTOMER_ORDER_METADATA_TABLES; do
   CMD="$CMD nice -10 $DUMP_CMD --no-create-info --tables $TABLE --where='order_id IN ($CUSTOMER_ORDER_IDS)';"
   eval "$DUMP"
done

CUSTOMER_ORDER_METADATA_TABLES="
sales_flat_order_address
sales_flat_order_payment
sales_flat_order_status_history
"

for TABLE in $CUSTOMER_ORDER_METADATA_TABLES; do
   CMD="$CMD nice -10 $DUMP_CMD --no-create-info --tables $TABLE --where='parent_id IN ($CUSTOMER_ORDER_IDS)';"
done

###################
# Customer Order Quote
###################

eval COMMAND=\$\("mysql $SCHEMA -e 'SELECT entity_id FROM sales_flat_quote WHERE customer_id IN ($CUSTOMER_IDS)'"\)

CUSTOMER_ORDER_QUOTE_IDS=

for OUTPUT in $COMMAND
do
    re='^[0-9]+$'
    if ! [[ $OUTPUT =~ $re ]] ; then
       continue
    elif [[ -z "$OUTPUT" ]] ; then
       continue
    fi

    CUSTOMER_ORDER_QUOTE_IDS="$CUSTOMER_ORDER_QUOTE_IDS, $OUTPUT"
done

CUSTOMER_ORDER_QUOTE_IDS=${CUSTOMER_ORDER_QUOTE_IDS:1:${#CUSTOMER_ORDER_QUOTE_IDS}}

CMD="$CMD nice -10 $DUMP_CMD --no-create-info --tables sales_flat_quote --where='entity_id IN ($CUSTOMER_ORDER_QUOTE_IDS)';"

CUSTOMER_ORDER_QUOTE_METADATA_TABLES="
sales_flat_quote_address
sales_flat_quote_item
sales_flat_quote_payment
"

for TABLE in $CUSTOMER_ORDER_QUOTE_METADATA_TABLES; do
   CMD="$CMD nice -10 $DUMP_CMD --no-create-info --tables $TABLE --where='quote_id IN ($CUSTOMER_ORDER_QUOTE_IDS)';"
done

###################
# Customer Order Quote Address
###################
eval COMMAND=\$\("mysql $SCHEMA -e 'SELECT address_id FROM sales_flat_quote_address WHERE quote_id IN ($CUSTOMER_ORDER_QUOTE_IDS)'"\)

CUSTOMER_ORDER_QUOTE_ADDRESS_IDS=

for OUTPUT in $COMMAND
do
    re='^[0-9]+$'
    if ! [[ $OUTPUT =~ $re ]] ; then
       continue
    elif [[ -z "$OUTPUT" ]] ; then
        continue
    fi

    CUSTOMER_ORDER_QUOTE_ADDRESS_IDS="$CUSTOMER_ORDER_QUOTE_ADDRESS_IDS, $OUTPUT"
done

CUSTOMER_ORDER_QUOTE_ADDRESS_IDS=${CUSTOMER_ORDER_QUOTE_ADDRESS_IDS:1:${#CUSTOMER_ORDER_QUOTE_ADDRESS_IDS}}

CMD="$CMD nice -10 $DUMP_CMD --no-create-info --tables sales_flat_quote_address_item --where='quote_address_id IN ($CUSTOMER_ORDER_QUOTE_ADDRESS_IDS)';"
CMD="$CMD nice -10 $DUMP_CMD --no-create-info --tables sales_flat_quote_shipping_rate --where='address_id IN ($CUSTOMER_ORDER_QUOTE_ADDRESS_IDS)';"

###################
# Customer Order Quote Item
###################
eval COMMAND=\$\("mysql $SCHEMA -e 'SELECT item_id FROM sales_flat_quote_item WHERE quote_id IN ($CUSTOMER_ORDER_QUOTE_IDS)'"\)

CUSTOMER_ORDER_QUOTE_ITEM_IDS=

for OUTPUT in $COMMAND
do
    re='^[0-9]+$'
    if ! [[ $OUTPUT =~ $re ]] ; then
       continue
    elif [[ -z "$OUTPUT" ]] ; then
       continue
    fi

    CUSTOMER_ORDER_QUOTE_ITEM_IDS="$CUSTOMER_ORDER_QUOTE_ITEM_IDS, $OUTPUT"
done

CUSTOMER_ORDER_QUOTE_ITEM_IDS=${CUSTOMER_ORDER_QUOTE_ITEM_IDS:1:${#CUSTOMER_ORDER_QUOTE_ITEM_IDS}}

CMD="$CMD nice -10 $DUMP_CMD --no-create-info --tables sales_flat_quote_item_option --where='item_id IN ($CUSTOMER_ORDER_QUOTE_ITEM_IDS)';"

###################
# Misc
###################

MISC_TABLES="
downloadable_link_purchased
enterprise_customerbalance
enterprise_customersegment_customer
enterprise_giftregistry_entity
enterprise_invitation
enterprise_reward
enterprise_rma
enterprise_rma_grid
gift_message
newsletter_subscriber
oauth_token
persistent_session
poll_vote
product_alert_price
product_alert_stock
rating_option_vote
rewards_customer_index_points
rewardssocial_facebook_like
sales_billing_agreement
sales_recurring_profile
salesrule_coupon_usage
salesrule_customer
tag_relation
wishlist
"

for TABLE in $MISC_TABLES; do
   CMD="$CMD nice -10 $DUMP_CMD --no-create-info --tables $TABLE --where='customer_id IN ($CUSTOMER_IDS)';"
done

if [ $IS_RAW == 1 ]; then
   CMD="($CMD) > $FILENAME.sql"
else
   CMD="($CMD) | nice -n 10 gzip -9 > $FILENAME.sql.gz"
fi

eval "$CMD"

echo "Done!"
exit 0

