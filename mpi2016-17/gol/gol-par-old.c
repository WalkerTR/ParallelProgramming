/***********************

Conway Game of Life

************************/

#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <mpi.h>
//#define DEBUG

int bwidth, bheight, nsteps;
int numprocs, rank, numrows;
int buffer_size;
void *buffer;
int i, j, n, im, ip, jm, jp, ni, nj, nsum, isum, gisum;
int **old, **new;
float x;
double start, end;
double rtime, grtime;

#ifdef DEBUG
double timings[10], gtimings[10];
#endif

// update board for step n
void doTimeStep() {

    // left-right boundary conditions
    #ifdef DEBUG
    timings[0] -= MPI_Wtime();
    #endif
    for (i = 1; i <= numrows; i++) {
        old[i][0] = old[i][bwidth];
        old[i][bwidth + 1] = old[i][1];
    }
    #ifdef DEBUG
    timings[0] += MPI_Wtime();
    #endif

    // Send rows to adjacent process
    #ifdef DEBUG
    timings[1] -= MPI_Wtime();
    #endif
    MPI_Bsend(old[1], nj, MPI_INT, (numprocs + rank - 1) % numprocs, 0, MPI_COMM_WORLD);
    MPI_Bsend(old[numrows], nj, MPI_INT, (rank + 1) % numprocs, 0, MPI_COMM_WORLD);
    #ifdef DEBUG
    timings[1] += MPI_Wtime();
    #endif

    // Receive rows from adjacent process
    #ifdef DEBUG
    timings[2] -= MPI_Wtime();
    #endif
    MPI_Recv(old[numrows + 1], nj, MPI_INT, (rank + 1) % numprocs, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    MPI_Recv(old[0], nj, MPI_INT, (numprocs + rank - 1) % numprocs, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    #ifdef DEBUG
    timings[2] += MPI_Wtime();
    #endif

    // update board
    #ifdef DEBUG
    timings[3] -= MPI_Wtime();
    #endif
    for (i = 1; i <= numrows; i++) {
        for (j = 1; j <= bwidth; j++) {
            im = i - 1;
            ip = i + 1;
            jm = j - 1;
            jp = j + 1;

            nsum = old[im][jp] + old[i][jp] + old[ip][jp]
                + old[im][j] + old[ip][j]
                + old[im][jm] + old[i][jm] + old[ip][jm];

            switch (nsum) {
            // a new organism is born
            case 3:
                new[i][j] = 1;
                break;
            // nothing happens
            case 2:
                new[i][j] = old[i][j];
                break;
            // the organism, if any, dies
            default:
                new[i][j] = 0;
            }
        }
    }
    #ifdef DEBUG
    timings[3] += MPI_Wtime();
    #endif

    // copy new state into old state
    #ifdef DEBUG
    timings[4] -= MPI_Wtime();
    #endif
    for (i = 1; i <= numrows; i++) {
        for (j = 1; j <= bwidth; j++) {
            old[i][j] = new[i][j];
        }
    }
    #ifdef DEBUG
    timings[4] += MPI_Wtime();
    #endif
}

int main(int argc, char *argv[]) {

    // Get Parameters
    if (argc != 4) {
        fprintf(stderr,
            "Usage: %s board_width board_height steps_count\n",
            argv[0]);
        exit(1);
    }
    bwidth = atoi(argv[1]);
    bheight = atoi(argv[2]);
    nsteps = atoi(argv[3]);

    #ifdef DEBUG
    for (i = 0; i < 10; i++) {
        timings[i] = 0;
    }
    #endif

    // MPI initialization
    MPI_Init(&argc, &argv);
    MPI_Comm_size(MPI_COMM_WORLD, &numprocs);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    // calculate number of rows for each process
    //
    // if bheight is not a multiple of numprocs
    // the first processes have one row more
    numrows = bheight / numprocs;
    if (rank < bheight % numprocs) {
        ++numrows;
    }

    if (rank == 0) {

        // this branch is used only by process 0
        // to send rows to all processes

        int **matrix;

        matrix = malloc(bheight*sizeof(int*));
        for (i = 0; i < bheight; i ++) {
            matrix[i] = malloc(bwidth*sizeof(int));
        }

        for (i = 0; i < bheight; i++) {
            for (j = 0; j < bwidth; j++) {
                x = rand()/((float)RAND_MAX + 1);
                if (x < 0.5) {
                    matrix[i][j] = 0;
                } else {
                    matrix[i][j] = 1;
                }
            }
        }

        MPI_Request requests[bheight];
        int rem = bheight % numprocs;
        int change = numrows * rem;
        int dest;

        //  initialize board
        for (i = 0; i < bheight; i++) {
            dest = (i < change) ?
                   (i / numrows) :
                   (i - change) / (bheight / numprocs) + rem;
            MPI_Isend(matrix[i], bwidth, MPI_INT, dest, 0, MPI_COMM_WORLD, requests + i);
        }

        for (i = 0; i < bheight; i++) {
            MPI_Wait(requests + i, MPI_STATUS_IGNORE);
            free(matrix[i]);
        }

        free(matrix);

    }

    // allocate arrays
    // add two for ghost cells
    ni = numrows + 2;
    nj = bwidth + 2;
    old = malloc(ni*sizeof(int*));
    new = malloc(ni*sizeof(int*));

    for (i = 0; i < ni; i++) {
        old[i] = malloc(nj*sizeof(int));
        new[i] = malloc(nj*sizeof(int));
    }

    // receive data from node 0
    for (i = 1; i <= numrows; i++) {
        MPI_Recv(old[i] + 1, bwidth, MPI_INT, 0, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    }

    // attach buffer for Bsend during iterations
    MPI_Pack_size(nj, MPI_INT, MPI_COMM_WORLD, &buffer_size);
    buffer_size += MPI_BSEND_OVERHEAD;
    // two rows are sent for each iteration and a
    // process can be already doing the next iteration
    buffer_size *= 4;
    buffer = malloc(buffer_size);
    MPI_Buffer_attach(buffer, buffer_size);


    MPI_Barrier(MPI_COMM_WORLD);

    start = MPI_Wtime();

    //  time steps
    for (n = 0; n < nsteps; n++) {
        doTimeStep();
    }

    end = MPI_Wtime();

    // compute running time
    rtime = end - start;

    // collect max runtime
    MPI_Reduce(&rtime, &grtime, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);

    // Iterations are done; sum the number of live cells
    isum = 0;
    for (i = 1; i <= numrows; i++) {
        for (j = 1; j <= bwidth; j++) {
            isum += old[i][j];
        }
    }

    // sum live cell among processes
    MPI_Reduce(&isum, &gisum, 1, MPI_INT, MPI_SUM, 0, MPI_COMM_WORLD);

    if (rank == 0) {
        printf("Number of live cells = %d\n", gisum);
        fprintf(stderr, "Game of Life took %10.3f seconds\n", grtime);
    }

    #ifdef DEBUG
    MPI_Reduce(&timings, &gtimings, 10, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
    for (i = 0; i < 10; i++) {
        if (rank == 0) {
            printf("Timing %i: %f\n", i, gtimings[i]);
        }
    }
    #endif

    MPI_Finalize();

    return 0;
}
