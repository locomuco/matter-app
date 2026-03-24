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
            object VendorID    { const val id: Long = 0x00000002L }
            object ProductID   { const val id: Long = 0x00000004L }
            object NodeLabel   { const val id: Long = 0x00000005L }
            object SoftwareVersionString { const val id: Long = 0x0000000AL }
        }
    }

    object Descriptor {
        const val ID: Long = 0x0000001DL

        object Attribute {
            object DeviceTypeList { const val id: Long = 0x00000000L }
        }
    }
}
