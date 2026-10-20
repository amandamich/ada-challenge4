import Foundation

struct BuildingZone: Identifiable, Hashable {
    let id: String
    var buildingName: String
    var floor: Int
    var zoneIdentifier: String
    var displayName: String

    init(
        buildingName: String,
        floor: Int,
        zoneIdentifier: String
    ) {
        self.buildingName = buildingName
        self.floor = floor
        self.zoneIdentifier = zoneIdentifier
        self.id = "\(buildingName)-\(floor)-\(zoneIdentifier)"
        self.displayName = "\(buildingName) - \(zoneIdentifier)"
    }
}

extension BuildingZone {
    static let buildings = ["Office"]
    static let floors = [1]
    static let zoneIdentifiers = [
        "Main Lab",
        "Foundation Lab",
        "Media Scape",
        "Flex Space",
        "Pantry",
        "Balkon Depan",
        "Balkon Belakang"
    ]

    static let defaultZone = BuildingZone(
        buildingName: buildings[0],
        floor: floors[0],
        zoneIdentifier: zoneIdentifiers[0]
    )

    static let allZones: [BuildingZone] = buildings.flatMap { building in
        floors.flatMap { floor in
            zoneIdentifiers.map { zone in
                BuildingZone(
                    buildingName: building,
                    floor: floor,
                    zoneIdentifier: zone
                )
            }
        }
    }
}
