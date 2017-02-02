package sokoban.bonus;

import ibis.ipl.*;

import java.io.IOException;
import java.util.List;
import java.util.Queue;
import java.util.concurrent.*;

public class Worker implements Runnable {

    private static BoardCache cache = new BoardCache();

    private Ibis ibis;
    private IbisIdentifier server;
    ExecutorService executor = Executors.newCachedThreadPool();
    SendPort resultsPort;

    public Worker(Ibis ibis, IbisIdentifier server) throws IOException {
        this.ibis = ibis;
        this.server = server;
    }

    @Override
    public void run() {
        try {
            SendPort greetsPort = ibis.createSendPort(Sokoban.greetsPortType);
            ReceivePort jobsPort = ibis.createReceivePort(Sokoban.jobSubmitPortType, null);
            resultsPort = ibis.createSendPort(Sokoban.resultsPortType);

            jobsPort.enableConnections();
            resultsPort.connect(server, "results");


            // greetings - sync point
            greetsPort.connect(server, "greets");
            WriteMessage greets = greetsPort.newMessage();
            greets.writeObject(jobsPort.identifier());
            greets.finish();
            greetsPort.close();

            ibis.registry().waitUntilTerminated();

            jobsPort.disableMessageUpcalls();
            resultsPort.close();
            jobsPort.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void jobsUpcall(ReadMessage message) throws IOException, ClassNotFoundException {
        Board[] jobs = null;
        message.readArray(jobs);

        for (Board job : jobs) {
            executor.execute(new JobTask(job));
        }

        message.finish();
    }

    private class JobTask implements Runnable {
        Board board;

        public JobTask(Board board) {
            this.board = board;
        }


        @Override
        public void run() {
            try {
                int sol = solutions(board);
                WriteMessage msg = resultsPort.newMessage();
                msg.writeInt(sol);
                msg.finish();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }



    /**
     * expands this board into all possible positions, and returns the number of
     * solutions. Will cut off at the bound set in the board.
     */
    private static int solutions(Board board) {
        int result = 0;

        if(board.isSolved()) {
            return 1;
        }

        if(board.getMoves() >= board.getBound()) {
            return 0;
        }

        List<Board> children = board.generateChildren(cache);

        for (Board child : children) {
            int childSolutions = solutions(child);

            if (childSolutions > 0) {
                result += childSolutions;
            }

            cache.put(child);
        }

        return result;
    }

}
