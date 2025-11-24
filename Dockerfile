# FROM apache/airflow:2.10.2
FROM apache/airflow:3.1.3

# Default user in the image is airflow, keep it
USER airflow

# Install the MySQL provider inside the image
RUN pip install --no-cache-dir pymysql sqlalchemy openpyxl
