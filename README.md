# PlatformCon - Azure Container Apps - Quick Hack 

## Introduction

This repo contains the solution shown during the ACA vs AKS PlatformCon session. 

## Prerequisites

- Azure subscription with owner rights
- VS Code or Visual Studio
- Azure CLI with Bicep
- REST Client or Postman VS code plugin or similar
- Clone this repo
- Build and run a C# console program

## Architecture

These are the Azure services that main.bicep will create. 

![Architecture](arch.png)

## Step by step guide

This section contains a step-by-step guide to setup and test the demos that was shown during the session. 

### 1. Create a resource group

Choose a postfix for the resource group name, five characters. e.g. "duxcf"
Replace [postfix] with your postfix in the following code, run the command.

```shell
az group create --name rg-[postfix] --location swedencentrals
```

### 2. Deploy the infrastructure using Bicep

Make sure the correct subscription is used by running. 

```shell
az account show
```

If the correct subscription is not shown run 

```shell
az account set -s [subscription name]
```

Deploy the infrastructure using the following command. This will deploy the infrastructure but not the container apps.    

```shell
az deployment group create -g rg-[postfix] -n mainDeploy -f infrastructure/main.bicep
```

This creates the Azure services to be used. Wait until the Azure services are deployed, open the Azure portal in a browser and copy the name of the Azure Container Registry, replace [acr] with this name in the next step.  

### 3. Build and push the container image in Azure registry

Use Azure Container Registry task to build the image and push it. Run the command, make sure the sourcecode is not opened in VS.  

```shell
az acr build -t platformcon/acaapi:1.0 -r [acr] AcaApi/.
```

### 4. Deploy the container apps
Run the command with the deploy=true parameter. 

```shell
az deployment group create -g rg-[postfix] -n mainDeploy -f infrastructure/main.bicep -p deploy=true
```

### 5. Configure the LoadConsole application 

Replace the values in brackets in LoadConsole/appsettings.json. 
Grab the unique string (5 characters) that has been created for all the azure services. e.g ns-abc12, then "abc12" is the unique string   
Grab the primary connection string for the servicebus. 

```shell
az servicebus namespace authorization-rule keys list -g rg-[postfix] --namespace-name ns-[unique string] --name RootManageSharedAccessKey --query primaryConnectionString -o tsv
```

Grab the primary url address for the container app.

```shell
az containerapp show -g rg-[postfix] --name superman --query properties.configuration.ingress.fqdn -o tsv
```

### 6. Run the LoadConsole 

The LoadConsole application is a .NET console application that can be run in a terminal. The application can be run in two ways, with the .NET CLI or with Docker.

The app takes 3 arguments

**Type**: http or queue | http endpoint or servicebus

**Requests**: int | number of requests for every thread 

**Threads**: int | number of threads to run 

if you run the app with the http type, the messages is sent to the url address for the container app.

![ACA scaling](scale.png)

if you run the app with the queue type, the messages is sent to servicebus.

![ACA scaling](daprize.png)

#### Run with the .NET CLI

Example "dotnet run --project ./LoadConsole/LoadConsole.csproj -- http 10 5" runs 10 requests on 5 threads to the http endpoint 

Http
```shell
dotnet run --project ./LoadConsole/LoadConsole.csproj http 10 5
```

Servicebus
```shell
dotnet run --project ./LoadConsole/LoadConsole.csproj queue 10 5
```
#### Run with Docker

Build the LoadConsole application docker container, run the command.

```shell
docker build -t loadconsole LoadConsole/.
```

Run the LoadConsole container with the following command.

Http
```shell
docker run -t loadconsole http 10 5
```

Servicebus
```shell
docker run -t loadconsole queue 10 5
```

#### Check logs inside container apps

Http
```shell
az containerapp logs show --name superman --resource-group rg-[postfix] --type console --follow
```

Servicebus
```shell
az containerapp logs show --name catwomen --resource-group rg-[postfix] --type console --follow
```
