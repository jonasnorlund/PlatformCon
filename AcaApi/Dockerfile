FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build-env
WORKDIR /app

# Copy necessary files and restore as distinct layer
COPY AcaApi.csproj ./
RUN dotnet restore

# Copy everything else and build
COPY . ./
RUN dotnet publish -c Release -o out AcaApi.csproj

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0
COPY --from=build-env /app/out .

# Start
ENTRYPOINT ["dotnet", "AcaApi.dll"]
