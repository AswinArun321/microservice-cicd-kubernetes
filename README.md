# CI/CD Pipeline and Kubernetes Deployment for a Microservice

A containerized **3-service microservice application** with an automated CI/CD pipeline using **GitHub Actions** and deployment to **Kubernetes**.

The project demonstrates how Docker, GitHub Actions, and Kubernetes can be combined to automate application testing, container image creation, and deployment.

## 🚀 Project Overview

The application consists of three independent services:

- **Auth Service** – Handles authentication-related functionality
- **API Service** – Handles application/API requests
- **Worker Service** – Handles background processing

Each service is containerized using Docker.

A GitHub Actions pipeline automatically runs on every commit to perform:

1. Code linting
2. Unit tests
3. Docker image build
4. Docker image push

The application can then be deployed to Kubernetes using Deployment, Service, and Ingress resources.

## 🏗️ Architecture

```text
                    Developer
                       |
                       | git push
                       v
                  GitHub Repository
                       |
                       v
                GitHub Actions
                       |
        +--------------+--------------+
        |              |              |
        v              v              v
      Lint          Unit Tests     Docker Build
                                      |
                                      v
                              Container Registry
                                      |
                                      v
                                 Kubernetes
                                      |
             +------------------------+------------------------+
             |                        |                        |
             v                        v                        v
        Auth Service             API Service             Worker Service
             |                        |                        |
             +------------------------+------------------------+
                                      |
                                      v
                                Kubernetes
                                  Ingress
```

## 🛠️ Technologies Used

| Technology | Purpose |
|---|---|
| Python | Application development |
| Docker | Containerization |
| Docker Compose | Local multi-service development |
| GitHub Actions | CI/CD automation |
| Kubernetes | Container orchestration |
| Minikube | Local Kubernetes cluster |
| EKS | Optional cloud Kubernetes deployment |
| Ingress | External application routing |
| GitHub Container Registry / Docker Hub | Container image storage |

## 📁 Project Structure

```text
microservice-cicd-kubernetes/
│
├── auth/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── ...
│
├── api/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── ...
│
├── worker/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── ...
│
├── k8s/
│   ├── auth-deployment.yaml
│   ├── auth-service.yaml
│   ├── api-deployment.yaml
│   ├── api-service.yaml
│   ├── worker-deployment.yaml
│   ├── worker-service.yaml
│   └── ingress.yaml
│
├── .github/
│   └── workflows/
│       └── ci-cd.yml
│
├── docker-compose.yml
└── README.md
```

> Adjust the filenames above if your actual project structure is different.

# 🐳 Docker

Each service has its own Dockerfile.

The services can be built independently:

```bash
docker build -t auth-service ./auth
docker build -t api-service ./api
docker build -t worker-service ./worker
```

## Run with Docker Compose

Start all services:

```bash
docker compose up --build
```

Run in detached mode:

```bash
docker compose up -d --build
```

Check running containers:

```bash
docker compose ps
```

Stop the application:

```bash
docker compose down
```

Docker Compose simplifies local development by starting the complete microservice application with a single command.

```text
docker compose up
        |
        +---- Auth
        |
        +---- API
        |
        +---- Worker
```

# 🔄 CI/CD Pipeline

The project uses **GitHub Actions** to automate the CI/CD workflow.

The pipeline runs when code is pushed to the repository.

## Pipeline Flow

```text
Git Push
   |
   v
Checkout Code
   |
   v
Install Dependencies
   |
   v
Lint
   |
   v
Run Unit Tests
   |
   v
Build Docker Images
   |
   v
Push Images to Container Registry
```

## GitHub Actions

The workflow is stored inside:

```text
.github/workflows/ci-cd.yml
```

A simplified workflow looks like:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches:
      - main

jobs:

  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          pip install -r requirements.txt

      - name: Run lint
        run: |
          # lint command

      - name: Run tests
        run: |
          # test command

  build:
    needs: test
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Build Docker images
        run: |
          docker build -t auth-service ./auth
          docker build -t api-service ./api
          docker build -t worker-service ./worker
```

> Keep the workflow in this README as documentation. Your actual `.github/workflows/ci-cd.yml` should contain the commands used by your project.

# ☸️ Kubernetes Deployment

The application can be deployed to Kubernetes using YAML manifests.

The deployment contains:

- Kubernetes Deployments
- Kubernetes Services
- Kubernetes Ingress

Each microservice runs as a separate Kubernetes workload.

```text
Kubernetes Cluster
│
├── Auth Deployment
│   └── Auth Service
│
├── API Deployment
│   └── API Service
│
├── Worker Deployment
│   └── Worker Service
│
└── Ingress
```

# 🖥️ Run Kubernetes Locally with Minikube

## 1. Start Minikube

```bash
minikube start
```

Check the cluster:

```bash
kubectl cluster-info
```

Check nodes:

```bash
kubectl get nodes
```

## 2. Apply Kubernetes Manifests

Apply the deployments:

```bash
kubectl apply -f k8s/
```

Check deployments:

```bash
kubectl get deployments
```

Check pods:

```bash
kubectl get pods
```

Check services:

```bash
kubectl get services
```

## 3. Enable Ingress

For Minikube:

```bash
minikube addons enable ingress
```

Check the Ingress:

```bash
kubectl get ingress
```

## 4. Access the Application

Depending on your Ingress configuration:

```bash
minikube ip
```

Use the returned IP address to access the application through the configured Ingress host.

# 🔍 Useful Kubernetes Commands

View all resources:

```bash
kubectl get all
```

View pods:

```bash
kubectl get pods
```

View pod logs:

```bash
kubectl logs <pod-name>
```

Describe a pod:

```bash
kubectl describe pod <pod-name>
```

View deployments:

```bash
kubectl get deployments
```

View services:

```bash
kubectl get svc
```

View ingress:

```bash
kubectl get ingress
```

Delete the Kubernetes resources:

```bash
kubectl delete -f k8s/
```

# 🔐 Container Registry

The Docker images generated by the CI/CD pipeline can be stored in a container registry.

Example:

```text
Container Registry
│
├── auth-service
├── api-service
└── worker-service
```

The Kubernetes deployment can then pull these images when creating the application pods.

For GitHub Container Registry, images can follow a format such as:

```text
ghcr.io/<username>/auth-service
ghcr.io/<username>/api-service
ghcr.io/<username>/worker-service
```

## 🔑 GitHub Actions Secrets

If your workflow requires registry credentials, configure them through:

```text
GitHub Repository
    ↓
Settings
    ↓
Secrets and variables
    ↓
Actions
```

Never hard-code passwords, access tokens, or registry credentials inside the workflow.

# 🌐 Kubernetes Ingress

Ingress provides a single entry point for routing external traffic to the appropriate Kubernetes service.

Example:

```text
                     Ingress
                        |
          +-------------+-------------+
          |             |             |
          v             v             v
       /auth          /api        /worker
          |             |             |
          v             v             v
       Auth Svc      API Svc      Worker Svc
```

The exact routing rules depend on the project's Ingress configuration.

# 🔁 Rolling Updates

Kubernetes Deployments allow new versions of the services to be rolled out without stopping the entire application.

```text
Old Version
     |
     v
New Version
     |
     v
Rolling Update
     |
     v
Updated Application
```

This supports the project's goal of achieving zero-downtime rolling updates across the three services.

# 📊 Project Results

The project demonstrates the following improvements:

- Local environment setup reduced to a single:

```bash
docker compose up
```

- Deployment steps automated through GitHub Actions.
- CI pipeline performs linting and unit testing.
- Docker images are automatically built and pushed.
- Three services are independently containerized.
- Kubernetes manages service deployment and networking.
- Kubernetes Deployment, Service, and Ingress manifests provide a repeatable deployment process.

The project reduced the deployment process from approximately **10 manual commands to a single automated GitHub Actions trigger**.

# 🎯 Learning Outcomes

This project demonstrates practical knowledge of:

- Microservice architecture
- Docker containerization
- Docker Compose
- CI/CD pipelines
- GitHub Actions
- Automated testing
- Docker image management
- Kubernetes Deployments
- Kubernetes Services
- Kubernetes Ingress
- Minikube
- Rolling updates
- Container orchestration

# 🔮 Future Enhancements

Possible improvements include:

- Add automated security scanning
- Add Kubernetes Secrets and ConfigMaps
- Add Helm charts
- Add Kubernetes Horizontal Pod Autoscaling
- Add Prometheus and Grafana monitoring
- Add centralized logging
- Add deployment to AWS EKS
- Add staging and production environments
- Add automated rollback on failed deployments
- Add infrastructure provisioning with Terraform

# 👨‍💻 Author

**Aswin Arunkumar A**

MSc Computer Science (Data Analytics)  
Rajagiri College of Social Sciences

GitHub: [AswinArun321](https://github.com/AswinArun321)

# 📄 License

This project is intended for educational and portfolio purposes.