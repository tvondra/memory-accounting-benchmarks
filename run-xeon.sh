#!/bin/bash

p=$PATH
d=/mnt/data/accounting


for s in 50 100 500; do

	for x in master patched; do

		PATH=/var/lib/postgresql/accounting/pg-$x/bin:$p

		which pg_ctl

		mkdir -p log/$x/$s

		killall -9 postgres
		rm -Rf $d

		echo `date` "initializing cluster $x $s"
		pg_ctl -D $d init > log/$x/$s/init.log 2>&1

		echo "work_mem = 1GB" >> $d/postgresql.conf
		echo "maintenance_work_mem = 1GB" >> $d/postgresql.conf
		echo "max_parallel_maintenance_workers = 0" >> $d/postgresql.conf
		echo "shared_buffers = 8GB" >> $d/postgresql.conf
		echo "max_wal_size = 32GB" >> $d/postgresql.conf

		pg_ctl -D $d/ -w -l log/$x/$s/pg.log start

		ps ax > log/$x/$s/ps.log

		createdb test

		echo `date` "initializing pgbench $x $s"
		pgbench -i -s $s test > log/$x/$s/bench.init.log 2>&1

		echo `date` "vacuum analyze $x $s"
		psql test -c 'vacuum analyze' >> log/$x/$s/bench.init.log 2>&1

		echo `date` "checkpoint $x $s"
		psql test -c 'checkpoint' >> log/$x/$s/bench.init.log 2>&1

		for r in `seq 1 100`; do

			echo `date` "run $r"
			/usr/bin/time -o log/$x/$s/time.log --append psql test >> log/$x/$s/results.log 2>&1 <<EOF
set trace_sort=on;
\timing on
reindex index pgbench_accounts_pkey;
EOF

			psql test -c "checkpoint" >> log/$x/$s/checkpoint.log 2>&1

		done

		pg_ctl -D $d/ -w stop

	done

done

