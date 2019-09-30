#!/bin/bash

p=$PATH
d=/mnt/data/accounting


for s in 10 25 50 200; do

	for x in master patched; do

		PATH=/var/lib/postgresql/accounting/pg-$x/bin:$p

		which pg_ctl

		mkdir -p log/$x/$s

		killall -9 postgres
		rm -Rf $d

		echo `date` "initializing cluster $x $s"
		pg_ctl -D $d init > log/$x/$s/init.log 2>&1

		echo "work_mem = 512MB" >> $d/postgresql.conf
		echo "maintenance_work_mem = 512MB" >> $d/postgresql.conf
		echo "max_parallel_maintenance_workers = 0" >> $d/postgresql.conf
		echo "shared_buffers = 1GB" >> $d/postgresql.conf

		pg_ctl -D $d/ -w -l log/$x/$s/pg.log start

		ps ax > log/$x/$s/ps.log 2>&1

		createdb test

		echo `date` "initializing pgbench $x $s"
		pgbench -i -s $s test > log/$x/$s/bench.init.log 2>&1

		echo `date` "vacuum analyze $x $s"
		psql test -c 'vacuum analyze' >> log/$x/$s/bench.init.log 2>&1

		echo `date` "checkpoint $x $s"
		psql test -c 'checkpoint' >> log/$x/$s/bench.init.log 2>&1

		for r in `seq 1 100`; do

			echo `date` "run $r"

			tps=`pgbench -n -S -M prepared -T 15 test | grep excluding | awk '{print $3}'`

			echo $tps >> log/$x/$s/results.log 2>&1

		done

		pg_ctl -D $d/ -w stop

	done

done

