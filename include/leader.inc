#if defined _leader_included_
  #endinput
#endif
#define _leader_included_
 
/**
 * Returns current leader
 *
 * @return int    Client index of the leader (-1 = null)
 */
native Leader_CurrentLeader();