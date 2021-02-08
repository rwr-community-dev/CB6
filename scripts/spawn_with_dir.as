#include "tracker.as"
#include "helpers.as"
#include "admin_manager.as"
#include "log.as"
#include "query_helpers.as"
#include "query_helpers2.as"
//code by square  (l2021 2 4)

class InvasionVehicle
{
	int id;
	string name;

	InvasionVehicle(int gid,string gname)
	{
		id=gid;
		name=gname;
	}
}


class SpawnWithDir : Tracker 
{
	protected Metagame@ m_metagame;
	protected array<InvasionVehicle@> invasionVehicles; 
	protected void reLine()
	{
		for(uint i=0;i<invasionVehicles.length();i++)
		{
			int u_id=invasionVehicles[i].id;
			string u_key=invasionVehicles[i].name;
			const XmlElement@ vehicleInfo = getVehicleInfo(m_metagame, u_id);
			string vehicleKey = vehicleInfo.getStringAttribute("key");
			if(vehicleKey!=u_key)
			{
				invasionVehicles.removeAt(i);
			}
		}
	}
	SpawnWithDir(Metagame@ metagame) 
	{
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	bool hasEnded() const {
		// always on
		return false;
	}

	// --------------------------------------------
	bool hasStarted() const {
		return true;
	}

	// --------------------------------------------
	protected void prepareType(const XmlElement@ event,string before,string ing,string after,string modname)
	{
			Vector3 tarPos = stringToVector3(event.getStringAttribute("position"));
			int goalId=searchVehicle(tarPos,before,4.0f);
			_log("search for step 1");
			if(goalId!=0x3f3f3f)
			{
				_log("gotit1");
				Vector3 tarDir = stringToVector3(getVehicleInfo(m_metagame,goalId).getStringAttribute("forward"));
				tarPos = stringToVector3(getVehicleInfo(m_metagame,goalId).getStringAttribute("position"));
				removeVehicle(m_metagame,goalId);
				invasionVehicles.insertLast(InvasionVehicle(goalId,before));
				
				spawnVehicleWithDir(ing,tarDir,tarPos);
				reLine();
				return ;
			}
			else
			{
				_log("search for step 2");
				goalId=searchVehicle(tarPos,ing,5.0f);
				if(goalId!=0x3f3f3f)
				{
				
					Vector3 tarDir = stringToVector3(getVehicleInfo(m_metagame,goalId).getStringAttribute("forward"));
					tarPos = stringToVector3(getVehicleInfo(m_metagame,goalId).getStringAttribute("position"));
					removeVehicle(m_metagame,goalId);
					invasionVehicles.insertLast(InvasionVehicle(goalId,ing));
					spawnVehicleWithDir(after,tarDir,tarPos);
					goalId=searchVehicle(tarPos,modname,10.0f);
					if(goalId!=0x3f3f3f)
					{
						destroyVehicle(m_metagame,goalId);
						invasionVehicles.insertLast(InvasionVehicle(goalId,modname));
					}
					reLine();
					return ;
				}
			}
	}
	protected void prepareVehicle(const XmlElement@ event,string before,string ing,string afterAp,string afterAt,string afterAu)
	{
		string type=event.getStringAttribute("key");
		if(type=="ap"&&afterAp!="none")
		{
			prepareType(event,before,ing,afterAp,"mod_ap.vehicle");
		}
		else if(type=="at"&&afterAt!="none")
		{
			prepareType(event,before,ing,afterAt,"mod_at.vehicle");
		}
		else if(type=="au"&&afterAu!="none")
		{
			prepareType(event,before,ing,afterAu,"mod_au.vehicle");
		}
	}



	protected void handleResultEvent(const XmlElement@ event) 
	{ 
		prepareVehicle(event,"vfs_sport.vehicle","vfs_modding.vehicle","vfs_ap.vehicle","vfs_at.vehicle","vfs_au.vehicle");
		prepareVehicle(event,"m113_sport.vehicle","m113_modding.vehicle","m113_tank_acav.vehicle","m113_tank_mortar.vehicle","none");
    }
	
	// --------------------------------------------
	int searchVehicle (Vector3 tarPos,string g_key,float rd) {
		_log("search for"+" "+g_key);
		float length=1145.0f;
		int id_out=0x3f3f3f;
		for (uint f = 0; f < 1; ++f)
		{
			array<const XmlElement@>@ vehicles = getAllVehicles(m_metagame, f);
			for (uint i = 0; i < vehicles.length(); ++i) 
			{
				if(getPositionDistance(tarPos,stringToVector3(vehicles[i].getStringAttribute("position")))>rd)continue;
				int vehicleId = vehicles[i].getIntAttribute("id");
				const XmlElement@ vehicleInfo = getVehicleInfo(m_metagame, vehicleId);
				string vehicleKey = vehicleInfo.getStringAttribute("key");
				if(vehicleKey!=g_key)continue;
				if(findIdInLine(vehicleId))continue;
				Vector3 vehiclePos = stringToVector3(vehicleInfo.getStringAttribute("position"));
				float n_length = getPositionDistance(tarPos, vehiclePos);
				if(n_length-length<=0.0f)
				{
					length=n_length;
					id_out=vehicleId;
				}
			}
		}
		if(id_out==0x3f3f3f)
		{
			_log("can't find");
			return 0x3f3f3f;
		}
		_log("get vehicle id "+id_out);
		return id_out; 
	}
	//---------------------------------------------------------------
	void spawnVehicleWithDir(string key,Vector3 dir,Vector3 pos)
	{
		XmlElement command("command");
		command.setStringAttribute("class", "create_instance");
		command.setIntAttribute("faction_id",0);
		command.setStringAttribute("instance_class","vehicle");
		command.setStringAttribute("instance_key",key);
		command.setStringAttribute("position",pos.toString());
		command.setStringAttribute("orientation","0 1 0 "+getA(dir[0],dir[2]));
		m_metagame.getComms().send(command);
	}
	//------------------------------------------------------------
	bool findIdInLine(int g_id)
	{
		for(uint i=0;i<invasionVehicles.length();i++)
		{
			if(g_id==invasionVehicles[i].id)
			{
				return true;
			}
		}
		return false;
	}
	//--------------------------------------------------------
	float getA(float x,float y)
	{
		float dis =sqrt((x*x)+(y*y));
		float x_t = x*(1.0f/dis);
		float y_t = y*(1.0f/dis);
		float ac = acos(x_t);
		if(asin(y_t)>0)
		{
			return (ac-1.57)*(-1.0f);
		}
		else
		{
			return (ac*(-1.0f)-1.57f)*(-1.0f);
		}
	}

	void update(float time) {
	}
}