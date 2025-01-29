FROM python:alpine

WORKDIR /app
COPY requirements.txt /app
RUN pip install --no-cache-dir -r requirements.txt

COPY replay.py /app
ENTRYPOINT ["python", "replay.py"]