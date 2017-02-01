all: gol-seq gol-par-old gol-par gol-par-omp

gol-seq: gol-seq.c
	gcc -Wall -O3 -o gol-seq gol-seq.c -lm

gol-par-old: gol-par-old.c
	mpicc -Wall -O3 -o gol-par-old gol-par-old.c

gol-par: gol-par.c
	mpicc -Wall -O3 -o gol-par gol-par.c

gol-par-omp: gol-par-omp.c
	mpicc -fopenmp -Wall -O3 -o gol-par-omp gol-par-omp.c

clean:
	rm -f *.o gol-seq gol-par-old gol-par gol-par-omp *~ *core
