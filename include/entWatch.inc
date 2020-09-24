#if defined _entWatch_include
  #endinput
#endif
#define _entWatch_include
 
//----------------------------------------------------------------------------------------------------
// Purpose: SMLib
//----------------------------------------------------------------------------------------------------
stock Entity_GetTargetName(entity, String:buffer[], size)
{
    return GetEntPropString(entity, Prop_Data, "m_iName", buffer, size);
}
 
//----------------------------------------------------------------------------------------------------
// Purpose: SMLib
//----------------------------------------------------------------------------------------------------
stock Entity_GetParentName(entity, String:buffer[], size)
{
    return GetEntPropString(entity, Prop_Data, "m_iParent", buffer, size);
}
 
//----------------------------------------------------------------------------------------------------
// Purpose: SMLib
//----------------------------------------------------------------------------------------------------
stock Entity_GetHammerID(entity)
{
    return GetEntProp(entity, Prop_Data, "m_iHammerID");
}
 
//----------------------------------------------------------------------------------------------------
// Purpose: SMLib
//----------------------------------------------------------------------------------------------------
stock Entity_GetClassName(entity, String:buffer[], size)
{
    GetEntPropString(entity, Prop_Data, "m_iClassname", buffer, size);
   
    if (buffer[0] == '\0') {
        return false;
    }
   
    return true;
}
 
//----------------------------------------------------------------------------------------------------
// Purpose: SMLib
//----------------------------------------------------------------------------------------------------
stock Entity_GetEntityFromHammerID(hammerID)
{
    for (new i = 0; i < GetEntityCount(); i++)
    {
        if (IsValidEdict(i))
        {
            if (Entity_GetHammerID(i) == hammerID)
            {
                return i;
            }
        }
    }
   
    return -1;
}
 
public SharedPlugin:__pl_entWatch =
{
    name = "entWatch",
    file = "entWatch.smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};