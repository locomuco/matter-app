package com.example.matter_home.chip

import chip.devicecontroller.ChipDeviceController
import chip.devicecontroller.ICDDeviceInfo

/**
 * No-op base implementation of [ChipDeviceController.CompletionListener].
 * Subclass and override only the callbacks you care about.
 *
 * Ported from CHIPTool's GenericChipDeviceListener.kt.
 */
open class GenericChipDeviceListener : ChipDeviceController.CompletionListener {
    override fun onConnectDeviceComplete() {}
    override fun onStatusUpdate(status: Int) {}
    override fun onPairingComplete(code: Long) {}
    override fun onPairingDeleted(code: Long) {}
    override fun onCommissioningComplete(nodeId: Long, errorCode: Long) {}
    override fun onReadCommissioningInfo(
        vendorId: Int, productId: Int,
        wifiEndpointId: Int, threadEndpointId: Int,
    ) {}
    override fun onCommissioningStatusUpdate(nodeId: Long, stage: String, errorCode: Long) {}
    override fun onCommissioningStageStart(nodeId: Long, stage: String) {}
    override fun onNotifyChipConnectionClosed() {}
    override fun onCloseBleComplete() {}
    override fun onError(error: Throwable?) {}
    override fun onOpCSRGenerationComplete(csr: ByteArray) {}
    override fun onICDRegistrationInfoRequired() {}
    override fun onICDRegistrationComplete(errorCode: Long, icdDeviceInfo: ICDDeviceInfo) {}
}
