<?xml version="1.0" encoding="UTF-8"?>
<!--
  Maintainer tool used to derive the checked-in QA pilot from a newly-created,
  landed Naev pilot.  It deliberately replaces all player-specific state.
-->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>
  <xsl:strip-space elements="*"/>

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="naev_save/version/naev">
    <naev>0.14.0-alpha.4+26-07-12-20.g1f5b5aa</naev>
  </xsl:template>

  <xsl:template match="naev_save/plugins">
    <plugins>
      <plugin id="joyride">Auxiliary Ship Bay</plugin>
      <plugin id="TXCrewmates">Crewmate companions</plugin>
    </plugins>
  </xsl:template>

  <xsl:template match="naev_save/diffs">
    <diffs><diff>hypergates_3</diff></diffs>
  </xsl:template>

  <xsl:template match="player/@name">
    <xsl:attribute name="name">Crewmates QA</xsl:attribute>
  </xsl:template>

  <xsl:template match="player/credits"><credits>50000000</credits></xsl:template>
  <xsl:template match="player/chapter"><chapter>1</chapter></xsl:template>
  <xsl:template match="player/fleet_capacity"><fleet_capacity>100</fleet_capacity></xsl:template>

  <xsl:template match="player/ship">
    <ship name="QA Carrier" model="Za'lek Hephaestus" favourite="1" deployed="0">
      <acquired>Purpose-built carrier for repeatable Crewmates manual testing.</acquired>
      <acquired_date>30187262871000</acquired_date>
      <time_played>0.000000</time_played>
      <dmg_done_shield>0.000000</dmg_done_shield>
      <dmg_done_armour>0.000000</dmg_done_armour>
      <dmg_taken_shield>0.000000</dmg_taken_shield>
      <dmg_taken_armour>0.000000</dmg_taken_armour>
      <jumped_times>0</jumped_times>
      <landed_times>1</landed_times>
      <death_counter>0</death_counter>
      <ships_destroyed>
        <Yacht>0</Yacht><Courier>0</Courier><Freighter>0</Freighter>
        <Armoured_Transport>0</Armoured_Transport><Bulk_Freighter>0</Bulk_Freighter>
        <Scout>0</Scout><Interceptor>0</Interceptor><Fighter>0</Fighter>
        <Bomber>0</Bomber><Corvette>0</Corvette><Destroyer>0</Destroyer>
        <Cruiser>0</Cruiser><Battleship>0</Battleship><Carrier>0</Carrier>
      </ships_destroyed>
      <fuel>2800.000000</fuel>
      <outfits_intrinsic/>
      <outfits_structure>
        <outfit slot="0" slotname="engines">Unicorp Eagle 3000 Engine</outfit>
        <outfit slot="1" slotname="engines_secondary">Unicorp Eagle 3000 Engine</outfit>
        <outfit slot="2" slotname="hull">Unicorp D-58 Heavy Plating</outfit>
        <outfit slot="3" slotname="hull_secondary">Unicorp D-58 Heavy Plating</outfit>
      </outfits_structure>
      <outfits_utility>
        <outfit slot="0" slotname="systems">Unicorp PT-440 Core System</outfit>
        <outfit slot="1" slotname="systems_secondary">Unicorp PT-440 Core System</outfit>
      </outfits_utility>
      <outfits_weapon>
        <outfit slot="0">Empire Lancelot Bay</outfit>
        <outfit slot="1">Empire Lancelot Bay</outfit>
        <outfit slot="4">Sirius Fidelity Bay</outfit>
        <outfit slot="5">Sirius Fidelity Bay</outfit>
        <outfit slot="6">Auxiliary Ship Bay</outfit>
      </outfits_weapon>
      <commodities/>
      <weaponsets autoweap="1" advweap="0" aim_lines="0">
        <weaponset inrange="1" manual="0" volley="0" id="0"/>
        <weaponset inrange="1" manual="0" volley="0" id="1"/>
        <weaponset inrange="1" manual="0" volley="0" id="2"/>
        <weaponset inrange="1" manual="0" volley="0" id="3"/>
        <weaponset inrange="1" manual="0" volley="0" id="4"/>
        <weaponset inrange="1" manual="0" volley="0" id="5"/>
        <weaponset inrange="1" manual="0" volley="0" id="6"/>
        <weaponset inrange="1" manual="0" volley="0" id="7"/>
        <weaponset inrange="1" manual="0" volley="0" id="8"/>
        <weaponset inrange="1" manual="0" volley="0" id="9"/>
        <weaponset inrange="1" manual="0" volley="0" id="10"/>
        <weaponset inrange="1" manual="0" volley="0" id="11"/>
      </weaponsets>
      <vars/>
    </ship>
  </xsl:template>

  <xsl:template match="player/ships"><ships/></xsl:template>
  <xsl:template match="missions"><missions/></xsl:template>
  <xsl:template match="events"><events/></xsl:template>
  <xsl:template match="news"><news/></xsl:template>

  <!-- Known-space entries can outlive the plugins that created their systems. -->
  <xsl:template match="space/known[
    @sys='Evolution Sandbox' or
    @sys='Multiplayer Arena' or
    @sys='Multiplayer Lobby' or
    @sys=&quot;Pyro's Pink Slip Storage&quot; or
    @sys=&quot;Somal's Ship Cemetery&quot;
  ]"/>

  <xsl:template match="events_done">
    <events_done>
      <done>start_event</done>
      <done>Chapter 1</done>
    </events_done>
  </xsl:template>

  <xsl:template match="naev_save/vars">
    <vars>
      <xsl:apply-templates select="var[@name='shipai_name' or @name='tut_disable']"/>
      <var name="_crewmates_qa_fixture" type="num">1.000000</var>
    </vars>
  </xsl:template>
</xsl:stylesheet>
