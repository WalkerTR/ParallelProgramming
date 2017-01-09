/***********************

Conway Game of Life

************************/

#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <mpi.h>

int bwidth, bheight, nsteps;
int numprocs, myid;
int numrows;
int buffer_size;
int i, j, n, im, ip, jm, jp, ni, nj, nsum, isum, gisum;
int **old, **new;
float x;
double start;
double end;
double rtime, grtime;
void *buffer;

// update board for step n
void doTimeStep() {

    // left-right boundary conditions
    for (i = 1; i <= numrows; i++) {
        old[i][0] = old[i][bwidth];
        old[i][bwidth + 1] = old[i][1];
    }

    // Send rows to adjacent process
    MPI_Bsend(old[1], nj, MPI_INT, (numprocs + myid - 1) % numprocs, 0, MPI_COMM_WORLD);
    MPI_Bsend(old[numrows], nj, MPI_INT, (myid + 1) % numprocs, 0, MPI_COMM_WORLD);

    // Receive rows from adjacent process
    MPI_Recv(old[numrows + 1], nj, MPI_INT, (myid + 1) % numprocs, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    MPI_Recv(old[0], nj, MPI_INT, (numprocs + myid - 1) % numprocs, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);

    // update board
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

    // copy new state into old state
    for (i = 1; i <= numrows; i++) {
        for (j = 1; j <= bwidth; j++) {
            old[i][j] = new[i][j];
        }
    }
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

    // MPI initialization
    MPI_Init(&argc, &argv);
    MPI_Comm_size(MPI_COMM_WORLD, &numprocs);
    MPI_Comm_rank(MPI_COMM_WORLD, &myid);

    // calculate number of rows for each process
    //
    // if bheight is not a multiple of numprocs
    // the first processes have one row more
    numrows = bheight / numprocs;
    if (myid < bheight % numprocs) {
        ++numrows;
    }

    // allocate arrays
    // add two for ghost cells
    ni = numrows + 2;
    nj = bwidth + 2;
    old = malloc(ni*sizeof(int*));
    new = malloc(ni*sizeof(int*));

    for(i=0; i<ni; i++) {
        old[i] = malloc(nj*sizeof(int));
        new[i] = malloc(nj*sizeof(int));
    }

    if (myid == 0) {

        // this branch is used only by process 0
        // to send rows to all processes

        // attach buffer which size include communication overhead
        MPI_Pack_size(bwidth, MPI_INT, MPI_COMM_WORLD, &buffer_size);
        buffer_size += MPI_BSEND_OVERHEAD; // add Bsend overhead
        buffer_size *= bheight; // multiply by number of total send
        buffer = malloc(buffer_size);
        MPI_Buffer_attach(buffer, buffer_size);


        int *row = malloc(bwidth*sizeof(int));

        int rem = bheight % numprocs;
        int change = numrows * rem;

        //  initialize board
        for(i=0; i<bheight; i++) {
            for(j=0; j<bwidth; j++) {
                x = rand()/((float)RAND_MAX + 1);
                if(x<0.5) {
                    row[j] = 0;
                } else {
                    row[j] = 1;
                }
            }
            int dest = (i < change) ?
                       (i / numrows) :
                       (i - change) / (bheight / numprocs) + rem;
            MPI_Bsend(row, bwidth, MPI_INT, dest, 0, MPI_COMM_WORLD);
        }

        free(row);

    }

    // receive data from node 0
    for(i=1; i<=numrows; i++) {
        MPI_Recv(old[i] + 1, bwidth, MPI_INT, 0, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    }

    // barrier to ensure all processes has already
    // receive data, so the buffer can be detached
    MPI_Barrier(MPI_COMM_WORLD);

    if (myid == 0) {
        MPI_Buffer_detach(buffer, &buffer_size);
    }

    // attach buffer for Bsend during iterations
    MPI_Pack_size(nj, MPI_INT, MPI_COMM_WORLD, &buffer_size);
    buffer_size += MPI_BSEND_OVERHEAD;
    // two rows are sent for each iteration and a
    // process can be already doing the next iteration
    buffer_size *= 4;
    buffer = malloc(buffer_size);
    MPI_Buffer_attach(buffer, buffer_size);

    start = MPI_Wtime();

    //  time steps
    for(n=0; n<nsteps; n++) {
        doTimeStep();
    }

    end = MPI_Wtime();

    // compute running time
    rtime = end - start;

    // collect max runtime
    MPI_Reduce(&rtime, &grtime, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);

    // Iterations are done; sum the number of live cells
    isum = 0;
    for(i=1; i<=numrows; i++) {
        for(j=1; j<=bwidth; j++) {
            isum += old[i][j];
        }
    }

    // sum live cell among processes
    MPI_Reduce(&isum, &gisum, 1, MPI_INT, MPI_SUM, 0, MPI_COMM_WORLD);

    if(myid == 0) {
        printf("Number of live cells = %d\n", gisum);
        fprintf(stderr, "Game of Life took %10.3f seconds\n", grtime);
    }

    MPI_Finalize();

    return 0;
}
