Write-Output ‘Getting PowerShell Module’

$result = Get-Module -ListAvailable |

Select-Object Name, Version, ModuleBase |

Sort-Object -Property Name |

Format-Table -wrap |

Out-String

Write-output `n$result