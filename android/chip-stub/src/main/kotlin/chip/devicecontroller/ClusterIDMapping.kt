package chip.devicecontroller

/**
 * Mirrors the real chip.devicecontroller.ClusterIDMapping generated class.
 * Only the clusters used by ClusterClient are stubbed here.
 */
object ClusterIDMapping {

    object OnOff {
        const val ID: Long = 0x00000006L

        object Attribute {
            object OnOff { const val id: Long = 0x00000000L }
        }

        object Command {
            object Off    { const val id: Long = 0x00000000L }
            object On     { const val id: Long = 0x00000001L }
            object Toggle { const val id: Long = 0x00000002L }
        }
    }

    object LevelControl {
        const val ID: Long = 0x00000008L

        object Command {
            object MoveToLevel { const val id: Long = 0x00000000L }
        }

        object MoveToLevelCommandField {
            object Level          { const val id: Int = 0 }
            object TransitionTime { const val id: Int = 1 }
            object OptionsMask    { const val id: Int = 3 }
            object OptionsOverride { const val id: Int = 4 }
        }
    }

    object BasicInformation {
        const val ID: Long = 0x00000028L

        object Attribute {
            object VendorID              { const val id: Long = 0x00000002L }
            object ProductID             { const val id: Long = 0x00000004L }
            object NodeLabel             { const val id: Long = 0x00000005L }
            object SoftwareVersionString { const val id: Long = 0x0000000AL }
            object SerialNumber          { const val id: Long = 0x0000000EL }
        }
    }

    object Descriptor {
        const val ID: Long = 0x0000001DL

        object Attribute {
            object DeviceTypeList { const val id: Long = 0x00000000L }
        }
    }

    object Thermostat {
        const val ID: Long = 0x00000201L

        object Attribute {
            object LocalTemperature            { const val id: Long = 0x00000000L }
            object OccupiedHeatingSetpoint     { const val id: Long = 0x00000012L }
            object OccupiedCoolingSetpoint     { const val id: Long = 0x00000011L }
            object SystemMode                  { const val id: Long = 0x0000001CL }
            object ControlSequenceOfOperation  { const val id: Long = 0x0000001BL }
        }

        object Command {
            object SetpointRaiseLower { const val id: Long = 0x00000000L }
        }
    }

    object RelativeHumidityMeasurement {
        const val ID: Long = 0x00000405L

        object Attribute {
            object MeasuredValue    { const val id: Long = 0x00000000L }
            object MinMeasuredValue { const val id: Long = 0x00000001L }
            object MaxMeasuredValue { const val id: Long = 0x00000002L }
        }
    }
}
