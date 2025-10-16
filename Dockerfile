# Step 1: Use official Python image
FROM python:3.11-slim

# Step 2: Set working directory
WORKDIR /app

# Step 3: Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Step 4: Copy all project files
COPY . .

# Step 5: Expose port 8000
EXPOSE 8000

# Step 6: Run FastAPI app
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
