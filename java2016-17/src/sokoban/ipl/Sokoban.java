package sokoban.ipl;

import ibis.ipl.*;

import java.io.FileNotFoundException;
import java.io.IOException;

public class Sokoban {

    static PortType jobSubmitPortType = new PortType(PortType.COMMUNICATION_RELIABLE,
            PortType.SERIALIZATION_OBJECT, PortType.RECEIVE_EXPLICIT,
            PortType.CONNECTION_ONE_TO_ONE);

    static PortType resultsPortType = new PortType(PortType.COMMUNICATION_RELIABLE,
            PortType.SERIALIZATION_DATA, PortType.RECEIVE_EXPLICIT,
            PortType.CONNECTION_MANY_TO_ONE);

    static PortType greetsPortType = new PortType(PortType.COMMUNICATION_RELIABLE,
            PortType.SERIALIZATION_OBJECT, PortType.RECEIVE_EXPLICIT,
            PortType.CONNECTION_MANY_TO_ONE);

    static IbisCapabilities ibisCapabilities = new IbisCapabilities(
            IbisCapabilities.ELECTIONS_STRICT,
            IbisCapabilities.CLOSED_WORLD);

    public static void main(String[] args) {
        try {
            Ibis ibis = IbisFactory.createIbis(ibisCapabilities, null,
                    jobSubmitPortType, greetsPortType, resultsPortType);
            IbisIdentifier server = ibis.registry().elect("Server");

            if (server.equals(ibis.identifier())) {
                Board board = null;

                if(args.length == 0) {
                    System.err.println("Input file not provided.");
                } else {
                    try {
                        board = new Board(args[0]);
                    } catch (FileNotFoundException e) {
                        System.err.println("Input file not found.");
                    }
                }

                Master master = new Master(ibis, board);
                Thread thread = new Thread(master);
                thread.start();
            }



            Worker worker = new Worker(ibis, server);
            worker.run();
            ibis.end();

        } catch (IbisCreationFailedException e) {
            e.printStackTrace(System.err);
        } catch (IOException e) {
            e.printStackTrace(System.err);
        }

    }

}
