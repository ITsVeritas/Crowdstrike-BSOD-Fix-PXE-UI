--Use this to export all recovery keys from ConfigMgr db and create the Keys.csv file
with cte as (
select Keys.RecoveryKeyId AS ID, RecoveryAndHardwareCore.DecryptString(Keys.RecoveryKey, DEFAULT) AS [Key], ROW_NUMBER() OVER(PARTITION BY Keys.RecoveryKeyId ORDER BY Keys.LastUpdateTime DESC) AS row_number
    from dbo.RecoveryAndHardwareCore_Machines Machines
    inner join dbo.RecoveryAndHardwareCore_Machines_Volumes Volumes ON Machines.Id = Volumes.MachineId
    inner join dbo.RecoveryAndHardwareCore_Keys Keys ON Volumes.VolumeId = Keys.VolumeId
)
select ID, [Key] from CTE where row_number = 1
