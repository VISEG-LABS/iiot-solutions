using '../main.bicep'

param namePrefix = 'visegconnect'
param location = 'westeurope'
param appServiceSku = 'B1'
param useSyntheticData = true
param logDailyCapGb = 1
param sqlAdministratorObjectId = readEnvironmentVariable('VISEG_SQL_ADMIN_OBJECT_ID')
