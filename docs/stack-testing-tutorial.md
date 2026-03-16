# End-to-End Testing Tutorial

This guide explains how to test the full telemetry stack from beginning to end in simple language. You do not need to understand the code to use it. The goal is to confirm that the whole system starts, moves data, shows the data on a dashboard, and shuts down cleanly.

## What you are testing

This project acts like a small factory telemetry system.

It has six parts working together:

1. A simulator that pretends to be an industrial machine.
2. A collector that reads values from the simulator.
3. A message broker that passes the values along.
4. A database writer that stores the values.
5. A database that keeps the history.
6. A Grafana dashboard that shows the data visually.

If the test works, you will see the system start, store live readings, show machine state changes and alarms, and display them in Grafana.

## Before you begin

Make sure these are ready on your computer:

- Docker Desktop is installed.
- Docker Desktop is running.
- You are inside the project folder:
  [MQTT Simulation](/C:/Users/salbot01/OneDrive/Desktop/Edge%20compute%20miniproject/MQTT%20Simulation)

Optional but helpful:

- Keep one browser tab ready for Grafana.
- Keep one PowerShell window open for commands.

## Step 1: Open the project folder

Open PowerShell and move into the project folder:

```powershell
cd "C:\Users\salbot01\OneDrive\Desktop\Edge compute miniproject\MQTT Simulation"
```

You are in the right place if you can see files such as `docker-compose.yml`, `README.md`, and folders like `services`, `infra`, and `contracts`.

## Step 2: Start the stack

Run this command:

```powershell
docker compose up --build
```

What this does in plain language:

- Builds the project services.
- Starts the simulator.
- Starts the message broker.
- Starts the database.
- Starts the dashboard.
- Starts the collector and ingestor that move the telemetry through the pipeline.

What to expect:

- The first run may take a few minutes.
- A lot of lines will scroll by in the PowerShell window.
- This is normal.

The stack is ready when you start seeing repeated activity instead of startup errors. Good signs include:

- the simulator updating values
- the collector publishing telemetry
- the ingestor flushing or writing data

If the screen stops on repeated error messages, leave it running for about 30 seconds first. Some services need a short time to wait for others to become available.

## Step 3: Open the dashboard

Once the stack is running, open this page in your browser:

[http://localhost:3000](http://localhost:3000)

Use these login details:

- Username: `admin`
- Password: `change_me_now`

After login, open the dashboard named `IIoT Telemetry Overview`.

What you should see:

- summary cards for healthy assets, faulted assets, output, and recent alarms
- an asset state board
- an alarm and event timeline
- a line telemetry trend chart
- a production and downtime KPI table

If the dashboard loads but looks empty, wait 15 to 30 seconds and refresh the page. The system may still be filling the database with its first readings.

## Step 4: Confirm that data is reaching the database

Open a second PowerShell window in the same project folder and run:

```powershell
docker compose exec timescaledb psql -U iiot -d iiot -c "SELECT * FROM telemetry ORDER BY ts DESC LIMIT 5;"
```

What this means in plain language:

- It opens the project database.
- It asks for the newest five telemetry records.

What success looks like:

- you see rows of data
- the rows contain times, asset names, signals, values, quality, and sequence numbers

If you get rows back, the telemetry pipeline is working all the way into storage.

You can also inspect the event history with:

```powershell
docker compose exec timescaledb psql -U iiot -d iiot -c "SELECT * FROM events ORDER BY ts DESC LIMIT 10;"
```

That should show machine state changes, alarm raises, alarm clears, and maintenance events.

## Step 5: Confirm that live values are changing

Run the same database command again after a few seconds:

```powershell
docker compose exec timescaledb psql -U iiot -d iiot -c "SELECT * FROM telemetry ORDER BY ts DESC LIMIT 5;"
```

Compare the new result with the earlier one.

Success signs:

- the timestamps are newer
- the sequence numbers are increasing
- the values are changing slightly over time

This tells you the simulator is still producing data and the stack is still carrying it through correctly.

## Step 6: Check the visual result in Grafana

Go back to Grafana and refresh the dashboard.

You want to confirm three simple things:

1. The asset state board is populated.
2. The alarm and event timeline is populated.
3. The time-series chart has drawn lines or points.

If both are visible, the full test is successful from start to finish:

- simulated machine data was generated
- the collector read it
- the broker carried it
- the ingestor stored it
- the database kept it
- Grafana displayed it

## Step 7: Optional quick health check

If you want a simple status view of the running services, open another PowerShell window and run:

```powershell
docker compose ps
```

What success looks like:

- the services appear in the list
- they show as running

This is a quick way to check whether one part stopped unexpectedly.

## Step 8: Stop the stack cleanly

When you are done testing, return to the PowerShell window where the stack is running and press `Ctrl + C`.

Then run:

```powershell
docker compose down
```

If you want to remove saved container data too, run:

```powershell
docker compose down -v
```

Use `-v` only if you want a completely fresh start next time.

## Simple pass or fail checklist

You can treat the full test as a pass if all of these are true:

- `docker compose up --build` starts the stack without getting stuck in permanent errors
- Grafana opens at `http://localhost:3000`
- the `IIoT Telemetry Overview` dashboard appears
- the database query returns telemetry rows
- the event query returns state or alarm records
- the values continue updating over time

If any one of those fails, the stack needs attention before you treat the demo as healthy.

## If something goes wrong

Here are the most common issues in plain language:

### Docker does not start

- Make sure Docker Desktop is open.
- Wait until Docker says it is running.
- Then try `docker compose up --build` again.

### Grafana page does not open

- Wait another 30 to 60 seconds.
- Refresh the page.
- If it still does not load, check `docker compose ps` to see whether the Grafana service is running.

### Database query shows no rows

- Wait 15 to 30 seconds and try again.
- The system may still be warming up.
- If rows still never appear, the collector or ingestor may not be running properly.

### Values are not changing

- Give it another few seconds.
- Refresh Grafana.
- Run the SQL check again.
- Static values usually mean the pipeline has stopped moving data.

## Best way to demo this project to someone else

If you are showing this stack to a lecturer, reviewer, or teammate, this is the smoothest flow:

1. Start the stack with `docker compose up --build`
2. Open Grafana in the browser
3. Show the state board, alarm timeline, and trend chart
4. Run the telemetry query in PowerShell
5. Run the events query in PowerShell
6. Run one of them again a few seconds later to show the data changing

That gives a clear story that the stack works from end to end.
