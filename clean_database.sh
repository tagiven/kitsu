#!/bin/bash


SYSBENCH_HOME="/usr/local/src/sysbench-trunk"    #Sysbench source code directory
CONFIG_FILE=".bench.cnf"
MYSQL_PORT="3306"

##### Functions

## print_help(): Print help statement and usage in case of invalid input
print_help() {
  echo "Usage:"
  echo "  test_database.sh [options]"
  echo ""
  echo "General options:"
  echo "  -u, --user          MySQL database user"
  echo "  -h, --host          MySQL database host"
  echo "  -p, --password      MySQL user password"
  echo "  -d, --database      database target for tests"
  echo "  -P, --port          port MySQL process is listening on"
  echo "  -t, --tables        number of tables to use during test"
  echo "  -e, --engine        storage engine used for test table"
  echo "  -l, --log           test execution output log"
  echo "  --test              test or testfile to execute (ex: /usr/local/sysbench-trunk/sysbench/tests/db/oltp.lua)"
  echo ""
}

## validate_numeric_input():  Validate numeric values are greater than 0
validate_numeric_input() {
  num_value=$1

  if [[ "${num_value}" -le 0 ]] ; then
    echo "ERROR: Invalid Parameter" | tee -a ${OUTPUT_LOG}
    print_help
    exit 1
  fi
}

## End of functions


## Begin main

# source  available
if [ -r ${CONFIG_FILE} ]; then
  source "${CONFIG_FILE}"
fi

# Parse Options
OPTS=`getopt -o u:h:d:p:P:t:r:e:l: --long user:,host:,database:,password:,port:,tables:,rows:,engine:,log: -- "$@"`
eval set -- "$OPTS"

while true
do
  case "$1" in
    -u|--user)
      MYSQL_USERNAME="$2"
      shift 2
      ;;
    -h|--host)
      MYSQL_HOST="$2"
      shift 2
      ;;
    -p|--password)
      MYSQL_PASSWORD="$2"
      shift 2
      ;;
    -d|--database)
      MYSQL_DATABASE="$2"
      shift 2
      ;;
    -P|--port)
      MYSQL_PORT="$2"
      shift 2
      ;;
    -t|--tables)
      NUM_TABLES="$2"
      shift 2
      ;;
    -r|--rows)
      TABLE_SIZE="$2"
      shift 2
      ;;
    -e|--engine)
      ENGINE="$2"
      shift 2
      ;;
    -l|--log)
      OUTPUT_LOG="$2"
      shift 2
      ;;
    --test)
      SYSBENCH_TEST="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Invalid options"
      exit 1
  esac
done

# Reset log file
> ${OUTPUT_LOG}

echo "Test Database Initialization"  >> ${OUTPUT_LOG}
echo "############################\n" >> ${OUTPUT_LOG}


# Check database for existing tables
########################################

## Get current table count for chosen database
current_tables=$(mysql -N -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} -P${MYSQL_PORT}  --database ${MYSQL_DATABASE} -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = '${MYSQL_DATABASE}';" 2>/dev/null)

if [[ "${current_tables}" -eq "0" ]] ; then
  echo "ERROR:  Requested database contains zero tables" | tee -a ${OUTPUT_LOG}
  exit 1
fi

## Start delete test tables
echo "Deleting test tables" >> ${OUTPUT_LOG}
echo "########################\n" >> ${OUTPUT_LOG}

sysbench --test=${SYSBENCH_HOME}${SYSBENCH_TEST}  --oltp-table-size=${TABLE_SIZE} --oltp-tables-count=${NUM_TABLES} --mysql-user=${MYSQL_USERNAME} --mysql-password=${MYSQL_PASSWORD} --mysql-host=${MYSQL_HOST} --mysql-port=${MYSQL_PORT} --mysql-db=${MYSQL_DATABASE} --mysql-table-engine=${ENGINE} cleanup >> ${OUTPUT_LOG}

echo "Test Table Cleanup process completed" >> ${OUTPUT_LOG}

# Clean up process completed

