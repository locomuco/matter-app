package chip.devicecontroller

import chip.devicecontroller.model.ChipAttributePath
import chip.devicecontroller.model.ChipEventPath
import chip.devicecontroller.model.InvokeElement
import chip.devicecontroller.model.NodeState

interface InvokeCallback {
    fun onError(ex: Exception?)
    fun onResponse(invokeElement: InvokeElement?, successCode: Long)
}

interface WriteAttributesCallback {
    fun onError(attributePath: ChipAttributePath?, ex: Exception)
    fun onResponse(attributePath: ChipAttributePath?, status: chip.devicecontroller.model.Status?)
    fun onDone() {}
}

interface ReportCallback {
    fun onError(
        attributePath: ChipAttributePath?,
        eventPath: ChipEventPath?,
        ex: Exception,
    )
    fun onReport(nodeState: NodeState?)
    fun onDone() {}
}

fun interface SubscriptionEstablishedCallback {
    fun onSubscriptionEstablished(subscriptionId: Long)
}

fun interface ResubscriptionAttemptCallback {
    fun onResubscriptionAttempt(
        terminationCause: Long,
        nextResubscribeIntervalMsec: Long,
    )
}
