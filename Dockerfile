FROM python:3.8-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DJANGO_SETTINGS_MODULE=demo.settings

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN python - <<'PY'
from pathlib import Path
p = Path('requirements.txt')
text = p.read_text('utf-16')
p.write_text(text, 'utf-8')
PY

RUN pip install --upgrade pip setuptools==65.5.0 wheel \
    && PIP_NO_BUILD_ISOLATION=1 pip install -r requirements.txt \
    && pip install gunicorn whitenoise

COPY . .

RUN python manage.py migrate --noinput \
    && python manage.py collectstatic --noinput

EXPOSE 8000
CMD ["gunicorn", "demo.wsgi:application", "--bind", "0.0.0.0:8000"]
