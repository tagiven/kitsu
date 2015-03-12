#!/bin/bash

# Default values
SYSBENCH_HOME="/usr/local/src/sysbench-trunk"    #Sysbench source code directory
CONFIG_FILE=".bench.cnf"
OUTPUT_LOG="bench-$(date +'%Y%m%d%H%M').log"
MYSQL_PORT="3306"
MYSQL_SSL="off"
READ_ONLY="off"

## Functions 

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
  echo "  --ssl               enable ssl ... [on|off]"
  echo "  --readonly          enable read only transactions ... [on|off]"
  echo "  -i, --iterations    number of iterations to execute tests"
  echo "  --time              time period of each test iteration"
  echo "  -T, --threads       number of concurrent database connection threads to use during test"
  echo "  -R, --request       maximum number of requests for test iteration"
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

## End of Functions

## Begining of Main

# source  available
if [ -r ${CONFIG_FILE} ]; then
  source "${CONFIG_FILE}"
fi

# Parse Options
OPTS=`getopt -o u:h:d:p:P:t:r:e:l:i:T:R --long user:,host:,database:,password:,port:,tables:,rows:,engine:,log:,iterations:,threads:,requests:,time:,ssl: -- "$@"`
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
    -i|--iterations)
      TEST_ITERATIONS="$2"
      shift 2
      ;;
    -T|--threads)
      CONNECTION_THREADS="$2"
      shift 2
      ;;
    -R|--requests)
      MAX_REQUESTS="$2"
      shift 2
      ;;
    --time)
      TEST_PERIOD="$2"
      shift 2
      ;;
    --ssl)
      MYSQL_SSL="$2"
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

# Reset log file > ${OUTPUT_LOG}

echo "Initializing test"  >> ${OUTPUT_LOG}
echo "############################\n" >> ${OUTPUT_LOG}


# Validate provided options
########################################

for i in ${NUM_TABLES} ${TABLE_SIZE} ${TEST_ITERATIONS} ${MAX_TIME} ${CONNECTION_THREADS} ${MAX_REQUESTS} ${TEST_PERIOD};
  do
  validate_numeric_input ${i} 
done

## Check database for existing tables
# Get current table count for chosen database
current_tables=$(mysql -N -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} -P${MYSQL_PORT} --database ${MYSQL_DATABASE} -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = '${MYSQL_DATABASE}';" 2>/dev/null)

if [[ "${current_tables}" -eq 0 ]] ; then
  echo "ERROR:  Bench test tables do not exist and must be initialized prior to test" | tee -a ${OUTPUT_LOG}
  exit 1
fi


## Prepare environment to handle requested thread count

# Increase test server file limit for requested thread count
MAX_FILES=$(ulimit -n)

if [[ $((${MAX_FILES}/2)) -le ${INIT_THREADS} ]] ; then
  echo "Increasing Max File limit for requested thread count" >> ${OUTPUT_LOG}
  ulimit -n $((${INIT_THREADS} * 2 ))
  echo "Updated ulimit: $(ulimit -n)" >> ${OUTPUT_LOG}
  echo "" >> ${OUTPUT_LOG}
fi

# Execute test for specified number of iterations

# Initialize  innodb buffer pool content and build active dataset in memory
echo "Starting Test" >> ${OUTPUT_LOG}
echo "###############################" >> ${OUTPUT_LOG}
echo "" >> ${OUTPUT_LOG}

for i in $(seq 1 ${TEST_ITERATIONS});
  do
  echo "Starting iteration ${i} - Threads: ${TEST_THREADS}" >> ${OUTPUT_LOG}
  echo "" >> ${OUTPUT_LOG}

  sysbench --test=${SYSBENCH_HOME}${SYSBENCH_TEST} --oltp-table-size=${TABLE_SIZE} --oltp-tables-count=${NUM_TABLES} --mysql-user=${MYSQL_USERNAME} --mysql-password=${MYSQL_PASSWORD} --mysql-host=${MYSQL_HOST} --mysql-port=${MYSQL_PORT} --mysql-db=${MYSQL_DATABASE} --max-time=${TEST_PERIOD} --num-threads=${CONNECTION_THREADS} --max-requests=${MAX_REQUESTS} --oltp-read-only=${READ_ONLY} --oltp-dist-type=uniform --report-interval=10 --mysql-ssl=${MYSQL_SSL} run >> ${OUTPUT_LOG}

  done
echo "####################" >> ${OUTPUT_LOG}
echo "Test Complete" >> ${OUTPUT_LOG}

##### End of main 
