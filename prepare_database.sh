#!/bin/bash

# Test Defaults
SYSBENCH_HOME="/usr/local/src/sysbench-trunk"    #Sysbench source code directory
CONFIG_FILE=".bench.cnf"
MYSQL_PORT="3306"

# Default Init parameters
INIT_TEST="/sysbench/tests/db/select.lua"
INIT_TIME=43200           # 12 hour default
INIT_THREADS=40           # max threads for 512 MB instance
INIT_REQUESTS=100000000   

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
  echo "  -r, --rows          number of rows per table"
  echo "  -e, --engine        storage engine used for test table"
  echo "  -l, --log           test execution output log"
  echo "  --test              test or testfile to execute (ex: /usr/local/sysbench-trunk/sysbench/tests/db/oltp.lua)"
  echo "  --time              time period to warm buffer pull"
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


## End Functions

## Begin Main

# source config file if present
if [ -r ${CONFIG_FILE} ]; then
  source "${CONFIG_FILE}"
fi

# Parse Options
OPTS=`getopt -o u:h:d:p:P:t:r:e:l: --long user:,host:,database:,password:,port:,tables:,rows:,engine:,log:,time: -- "$@"`
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
    --time)
      INIT_TIME="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Invalid options"
      print_help
      exit 1
  esac
done

# Reset log file
> ${OUTPUT_LOG}

# Validate provided options
########################################

for i in ${NUM_TABLES} ${TABLE_SIZE} ${INIT_TIME} ${INIT_THREADS} ${INIT_MAX_REQUESTS} ;
  do
  validate_numeric_input ${i} 
done


echo "Test Database Initialization"  >> ${OUTPUT_LOG}
echo "############################\n" >> ${OUTPUT_LOG}


# Check database for existing tables
########################################

## Get current table count for chosen database
current_tables=$(mysql -N -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} -P${MYSQL_PORT} --database ${MYSQL_DATABASE} -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = '${MYSQL_DATABASE}';" 2>/dev/null)

if [[ "${current_tables}" -ne 0 ]] ; then
  echo "ERROR:  Bench test tables already exist and must be deleted prior to preparing a new test set" | tee -a ${OUTPUT_LOG}
  exit 1
fi

## Start building test tables
echo "Building new tables" >> ${OUTPUT_LOG}
echo "########################\n" >> ${OUTPUT_LOG}

sysbench --test=${SYSBENCH_HOME}${INIT_TEST}  --oltp-table-size=${TABLE_SIZE} --oltp-tables-count=${NUM_TABLES} --mysql-user=${MYSQL_USERNAME} --mysql-password=${MYSQL_PASSWORD} --mysql-host=${MYSQL_HOST} --mysql-port=${MYSQL_PORT} --mysql-db=${MYSQL_DATABASE} --mysql-table-engine=${ENGINE} prepare >> ${OUTPUT_LOG}

echo "Table build completed" >> ${OUTPUT_LOG}


## Initialize database buffers

# Increase test server file limit for requested thread count
MAX_FILES=$(ulimit -n)

if [[ $((${MAX_FILES}/2)) -le ${INIT_THREADS} ]] ; then
  echo "Increasing Max File limit for requested thread count" >> ${OUTPUT_LOG}
  ulimit -n $((${INIT_THREADS} * 2 ))
  echo "Updated ulimit: $(ulimit -n)" >> ${OUTPUT_LOG}
  echo "" >> ${OUTPUT_LOG}
fi


# Initialize  innodb buffer pool content and build active dataset in memory
echo "Initializing InnoDB Buffer Pool" >> ${OUTPUT_LOG}
echo "###############################" >> ${OUTPUT_LOG}
echo "" >> ${OUTPUT_LOG}
echo "The initialization process will require 12 hours to complete" >> ${OUTPUT_LOG}
echo "" >> ${OUTPUT_LOG}

sysbench --test=${SYSBENCH_HOME}${INIT_TEST} --oltp-table-size=${TABLE_SIZE} --oltp-tables-count=${NUM_TABLES} --mysql-user=${MYSQL_USERNAME} --mysql-password=${MYSQL_PASSWORD} --mysql-host=${MYSQL_HOST} --mysql-port=${MYSQL_PORT} --mysql-db=${MYSQL_DATABASE} --max-time=${INIT_TIME} --num-threads=${INIT_THREADS} --max-requests=${INIT_MAX_REQUESTS}  run >> ${OUTPUT_LOG}

echo "####################" >> ${OUTPUT_LOG}
echo "Initization Complete" >> ${OUTPUT_LOG}

##### End of main 

