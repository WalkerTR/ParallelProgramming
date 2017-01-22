package sokoban.ipl;

import ibis.ipl.*;

import java.io.IOException;
import java.util.List;

public class Worker implements Runnable {

    private static BoardCache cache = new BoardCache();

    private Ibis ibis;
    private IbisIdentifier server;

    public Worker(Ibis ibis, IbisIdentifier server) throws IOException {
        this.ibis = ibis;
        this.server = server;
    }

    @Override
    public void run() {
        try {
            SendPort greetsPort = ibis.createSendPort(Sokoban.greetsPortType);
            ReceivePort jobsPort = ibis.createReceivePort(Sokoban.jobSubmitPortType, null);
            SendPort resultsPort = ibis.createSendPort(Sokoban.resultsPortType);

            greetsPort.connect(server, "greets");
            WriteMessage greets = greetsPort.newMessage();
            greets.writeObject(jobsPort.identifier());
            greets.finish();
            greetsPort.close();

            jobsPort.enableConnections();
            resultsPort.connect(server, "results");

            // synchronization point
            resultsPort.newMessage().finish();

            Board board;
            long tt = 0;
            boolean first = true;
            do {
                if (!first) tt -= System.currentTimeMillis();
                ReadMessage read = jobsPort.receive();
                if (!first) tt += System.currentTimeMillis();
                board = (Board) read.readObject();
                read.finish();
                first = false;

                if (board != null) {
                    int sol = solutions(board);
                    WriteMessage message = resultsPort.newMessage();
                    message.writeInt(sol);
                    message.finish();
                }
            } while (board != null);
            resultsPort.close();
            jobsPort.close();
            System.out.println("Worker waited for " + tt + " millis");
        } catch (IOException e) {
            e.printStackTrace();
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
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
