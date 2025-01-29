# Starting Replayer

## Using Docker Compose

The easiest way to start replay client (replayer) is using docker compose. If you are in the root of the repository you can run

```bash
docker compose run -it --rm --name replayer replayer
```

This builds and then runs the image interactively in a container named replayer.

## Using Docker / Podman

Alternatively you can emulate what docker compose does with docker (or podman).

Assuming you are in the root of the repository:

1. **Build the image**

   ```bash
   docker build -t replay-app -f scripts/replay/Dockerfile scripts/replay
   ```

2. **Run the container**

   ```bash
   docker run -it --network host --env-file .env -v ./data/prices:/data replay-app -p /data -s 100
   ```

​	This starts the replayer with a speed factor of 100  (`-s 100`)

## Run Replay Locally

You can also setup a python environment with [requirements.txt](requirements.txt) installed.

Assuming you are in `scripts/replay` and you have [python](https://www.python.org/downloads/)) installed :

1. **Create a Virtual Environment** 

   ```bash
   python -m venv .venv
   ```

2. **Activate the Virtual Environment**

   ```bash
   source .venv/bin/activate
   ```

3. **Install Requirements**

   ```bash
   pip install -r requirements.txt
   ```

4. **Run Replayer**

   ```bash
   source ../../.env && python replay.py -p ../../data/prices -s 100
   ```

   Assuming your prices are in `data/prices` 