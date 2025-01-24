FROM python:3.12-slim

RUN apt-get update && apt-get install -y build-essential git curl
RUN pip install pipenv
RUN git clone https://github.com/wireapp/wire-docs.git
WORKDIR wire-docs
RUN PIPENV_PIPFILE="build/Pipfile" pipenv install --ignore-pipfile
RUN bash build/build_versions.sh
EXPOSE 8000
CMD ["pipenv", "run", "mike", "serve", "-a", "0.0.0.0:8000"]
