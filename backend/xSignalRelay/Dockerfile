FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY xSignalRelay.csproj .
RUN dotnet restore xSignalRelay.csproj

COPY . .
RUN dotnet publish xSignalRelay.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

COPY --from=build /app .

ENTRYPOINT ["dotnet", "xSignalRelay.dll"]
