kitsu benchtests
================

Tests utilizing sysbench 0.5 
https://blog.mariadb.org/using-lua-enabled-sysbench/

# Test config file
.bench.cnf

All configuration options can also be passed via command line.  

# Build test dataset and initialize buffers
prepare_database.sh

# Clean up test data when completed
clean_database.sh

# Test initialized database
test_database.sh
