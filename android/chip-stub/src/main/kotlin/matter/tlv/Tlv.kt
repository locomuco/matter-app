package matter.tlv

import chip.ChipSdkStubException

object AnonymousTag

class ContextSpecificTag(val tagNumber: Int)

class TlvWriter {
    fun startStructure(tag: Any): TlvWriter = throw ChipSdkStubException()
    fun put(tag: Any, value: UInt): TlvWriter = throw ChipSdkStubException()
    fun put(tag: Any, value: Boolean): TlvWriter = throw ChipSdkStubException()
    fun put(tag: Any, value: Int): TlvWriter = throw ChipSdkStubException()
    fun endStructure(): TlvWriter = throw ChipSdkStubException()
    fun getEncoded(): ByteArray = throw ChipSdkStubException()
}

class TlvReader(val bytes: ByteArray) {
    fun getBool(tag: Any): Boolean = throw ChipSdkStubException()
    fun getLong(tag: Any): Long = throw ChipSdkStubException()
    fun getULong(tag: Any): ULong = throw ChipSdkStubException()
    fun getUInt(tag: Any): Int = throw ChipSdkStubException()
    fun getInt(tag: Any): Int = throw ChipSdkStubException()
    fun getUtf8String(tag: Any): String = throw ChipSdkStubException()
    fun getString(tag: Any): String = throw ChipSdkStubException()
    fun enterArray(tag: Any): Unit = throw ChipSdkStubException()
    fun enterStructure(tag: Any): Unit = throw ChipSdkStubException()
    fun enterList(tag: Any): Unit = throw ChipSdkStubException()
    fun exitContainer(): Unit = throw ChipSdkStubException()
    fun isEndOfContainer(): Boolean = throw ChipSdkStubException()
    fun isEndOfTlv(): Boolean = throw ChipSdkStubException()
    fun skipElement(): Unit = throw ChipSdkStubException()
    fun toAny(): Any? = throw ChipSdkStubException()
}
