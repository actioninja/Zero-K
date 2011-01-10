unitDef = {
  unitname                      = [[factoryshield]],
  name                          = [[Shield Bot Factory]],
  description                   = [[Produces Tough Robots, Builds at 6 m/s]],
  acceleration                  = 0,
  bmcode                        = [[0]],
  brakeRate                     = 0,
  buildCostEnergy               = 550,
  buildCostMetal                = 550,
  builder                       = true,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX      = 7,
  buildingGroundDecalSizeY      = 7,
  buildingGroundDecalType       = [[factoryshield_aoplane.dds]],

  buildoptions                  = {
    [[cornecro]],
    [[corak]],
    [[corstorm]],
    [[corthud]],
    [[cormak]],
    [[corcrash]],
    [[corclog]],
    [[corroach]],
    [[core_spectre]],
  },

  buildPic                      = [[factoryshield.png]],
  buildTime                     = 550,
  canMove                       = true,
  canPatrol                     = true,
  canstop                       = [[1]],
  category                      = [[SINK UNARMED]],
  collisionVolumeTest           = 1,
  corpse                        = [[DEAD]],

  customParams                  = {
    description_es = [[Produce robot de infanter?a. Construye a 6 m/s]],
    description_fi = [[Jalkav?kirobottitehdas. Rakentaa jalkav?kirobotteja 6m/s nopeudella]],
    description_fr = [[Produit des Robots d'Infanterie L. une vitesse de 6 m/s]],
    description_it = [[Produce robot d'infanteria. Costruisce a 6 m/s]],
    helptext       = [[The Shield Bot Fac is tough yet flexible. Its units are built to take the pain and dish it back out, without compromising mobility. Clever use of unit combos is well rewarded. Key units: Bandit, Thug, Outlaw, Roach, Clogger]],
    helptext_es    = [[El Infantry Bot Factory es una f?brica ideal para maniobras t?cticas en terreno dif?cil, con una selecci?n diversa de unidades invasoras, escaramuzadoras, y para alboroto. Lo que no tiene en feurza lo compensa con mobilidad y n?mero.]],
    helptext_fi    = [[Soveltuu hyvin taktisten ja vaikeassa maastossa p?rj??vien, joskin kest?vyydelt??n suhteellisen heikkojen robottien rakentamiseen.]],
    helptext_it    = [[L'Infantry Bot Factory ? una fabbrica ideale per manovre tattiche in terreno difficile, con una selezione diversa di unit? da invasione, da scaramuccia, e da rissa. Quello che gli manca in forza lo recupera in mobilit? e numeri.]],
    sortName       = [[1]],
  },

  energyMake                    = 0.15,
  energyUse                     = 0,
  explodeAs                     = [[LARGE_BUILDINGEX]],
  footprintX                    = 6,
  footprintZ                    = 6,
  iconType                      = [[facwalker]],
  idleAutoHeal                  = 5,
  idleTime                      = 1800,
  mass                          = 324,
  maxDamage                     = 4000,
  maxSlope                      = 15,
  maxVelocity                   = 0,
  maxWaterDepth                 = 0,
  metalMake                     = 0.15,
  minCloakDistance              = 150,
  noAutoFire                    = false,
  objectName                    = [[factory.s3o]],
  seismicSignature              = 4,
  selfDestructAs                = [[LARGE_BUILDINGEX]],
  showNanoSpray                 = false,
  side                          = [[ARM]],
  sightDistance                 = 273,
  smoothAnim                    = true,
  TEDClass                      = [[PLANT]],
  turnRate                      = 0,
  useBuildingGroundDecal        = true,
  workerTime                    = 6,
  yardMap                       = [[occccooccccooccccooccccooccccoocccco]],

  featureDefs                   = {

    DEAD  = {
      description      = [[Wreckage - Shield Bot Factory]],
      blocking         = true,
      category         = [[corpses]],
      damage           = 4000,
      energy           = 0,
      featureDead      = [[DEAD2]],
      featurereclamate = [[SMUDGE01]],
      footprintX       = 5,
      footprintZ       = 6,
      height           = [[40]],
      hitdensity       = [[100]],
      metal            = 220,
      object           = [[factory_dead.s3o]],
      reclaimable      = true,
      reclaimTime      = 220,
      seqnamereclamate = [[TREE1RECLAMATE]],
      world            = [[All Worlds]],
    },


    DEAD2 = {
      description      = [[Debris - Shield Bot Factory]],
      blocking         = false,
      category         = [[heaps]],
      damage           = 4000,
      energy           = 0,
      featureDead      = [[HEAP]],
      featurereclamate = [[SMUDGE01]],
      footprintX       = 5,
      footprintZ       = 5,
      height           = [[4]],
      hitdensity       = [[100]],
      metal            = 220,
      object           = [[debris4x4a.s3o]],
      reclaimable      = true,
      reclaimTime      = 220,
      seqnamereclamate = [[TREE1RECLAMATE]],
      world            = [[All Worlds]],
    },


    HEAP  = {
      description      = [[Debris - Shield Bot Factory]],
      blocking         = false,
      category         = [[heaps]],
      damage           = 4000,
      energy           = 0,
      featurereclamate = [[SMUDGE01]],
      footprintX       = 5,
      footprintZ       = 5,
      height           = [[4]],
      hitdensity       = [[100]],
      metal            = 110,
      object           = [[debris4x4a.s3o]],
      reclaimable      = true,
      reclaimTime      = 110,
      seqnamereclamate = [[TREE1RECLAMATE]],
      world            = [[All Worlds]],
    },

  },

}

return lowerkeys({ factoryshield = unitDef })
