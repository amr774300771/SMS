package com.qadinet.cardbot

import android.app.Notification
import android.content.Context
import android.content.ContextWrapper
import android.os.Bundle
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File
import java.nio.file.Files

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class WhatsAppAutoReplyTest {
    private val tempRoot = Files.createTempDirectory("cardbot-whatsapp-auto").toFile()
    private val context: Context = object : ContextWrapper(RuntimeEnvironment.getApplication()) {
        override fun getFilesDir(): File = tempRoot
    }

    private fun defaults(autoReply: Boolean) = mapOf(
        "packages.json" to """{"schemaVersion":1,"packages":[{"id":"500","price":500,"label":"500","keywords":["500"]}]}""",
        "permissions.json" to """{"global":{"allowAllClients":true,"allowedPackages":["500"],"maxDebt":50000,"maxDailyTransactions":10,"maxDailyAmount":100000},"clients":[]}""",
        "trigger_config.json" to """{"triggerEnabled":true,"whatsappAutoReplyEnabled":$autoReply,"processedCount":0,"totalSalesCount":0,"errorCount":0}""",
        "trusted_clients.json" to """{"filterEnabled":false,"clients":[{"phone":"700000000","name":"عميل اختبار"},{"phone":"700000001","name":"اسم مكرر"},{"phone":"700000002","name":"اسم مكرر"}]}""",
        "transactions.json" to """{"schemaVersion":1,"transactions":[]}""",
        "debts.txt" to "",
        "sales.log" to ""
    )

    @After
    fun cleanup() {
        tempRoot.deleteRecursively()
    }

    @Test
    fun enabledWhatsAppOrderSellsOnceAndRepliesThroughProvidedAction() {
        NativeStore.initialize(context, defaults(autoReply = true))
        NativeStore.addCards(context, "500", listOf("WA-CARD-500"))
        val replies = mutableListOf<String>()

        NativeStore.processIncoming(context, "700000000", "500", channel = "whatsapp") {
            replies.add(it)
            true
        }

        val snapshot = NativeStore.snapshot(context)
        assertEquals(1, (snapshot["sales"] as List<*>).size)
        assertEquals(emptyList<String>(), (snapshot["inventory"] as Map<*, *>) ["500"])
        assertEquals(1, replies.size)
        assertTrue(replies.single().contains("WA-CARD-500"))
        assertTrue(replies.single().contains("500"))
    }

    @Test
    fun WhatsAppAutoReplyIsDisabledByDefaultAndDoesNotSell() {
        NativeStore.initialize(context, defaults(autoReply = false))
        NativeStore.addCards(context, "500", listOf("WA-CARD-KEEP"))
        val replies = mutableListOf<String>()

        NativeStore.processIncoming(context, "700000000", "500", channel = "whatsapp") {
            replies.add(it)
            true
        }

        val snapshot = NativeStore.snapshot(context)
        assertTrue((snapshot["sales"] as List<*>).isEmpty())
        assertEquals(listOf("WA-CARD-KEEP"), (snapshot["inventory"] as Map<*, *>) ["500"])
        assertTrue(replies.isEmpty())
    }

    @Test
    fun trustedNameResolutionRequiresOneExactUniqueMatch() {
        NativeStore.initialize(context, defaults(autoReply = false))

        assertEquals("700000000", NativeStore.trustedPhoneForWhatsAppLabel(context, "  عميل   اختبار "))
        assertNull(NativeStore.trustedPhoneForWhatsAppLabel(context, "اسم مكرر"))
        assertNull(NativeStore.trustedPhoneForWhatsAppLabel(context, "عميل غير مسجل"))
    }

    @Test
    fun notificationWithMatchingConversationTitleIsStillTreatedAsOneToOne() {
        val extras = Bundle().apply {
            putCharSequence(Notification.EXTRA_TITLE, "عميل اختبار")
            putCharSequence(Notification.EXTRA_CONVERSATION_TITLE, "عميل اختبار")
        }
        assertEquals(false, WhatsAppNotificationListener.isGroupConversation(extras, 35))
        extras.putBoolean(Notification.EXTRA_IS_GROUP_CONVERSATION, true)
        assertTrue(WhatsAppNotificationListener.isGroupConversation(extras, 35))
    }

    @Test
    fun blankBigTextFallsBackToNonBlankNotificationText() {
        val extras = Bundle().apply {
            putCharSequence(Notification.EXTRA_BIG_TEXT, "  ")
            putCharSequence(Notification.EXTRA_TEXT, "500")
        }
        assertEquals("500", WhatsAppNotificationListener.extractNotificationMessage(extras))
    }

    @Test
    fun explicitOneToOneClassificationOverridesDifferentConversationTitle() {
        val extras = Bundle().apply {
            putBoolean(Notification.EXTRA_IS_GROUP_CONVERSATION, false)
            putCharSequence(Notification.EXTRA_TITLE, "عميل")
            putCharSequence(Notification.EXTRA_CONVERSATION_TITLE, "القاضي نت")
        }
        assertEquals(false, WhatsAppNotificationListener.isGroupConversation(extras, 35))
    }

    @Test
    fun repeatedIdenticalMessageInLaterNotificationHasItsOwnDedupeIdentity() {
        val first = WhatsAppNotificationListener.notificationDedupeDigest(
            "whatsapp|conversation", 1000L, "700000000", "500"
        )
        val repeated = WhatsAppNotificationListener.notificationDedupeDigest(
            "whatsapp|conversation", 2000L, "700000000", "500"
        )
        val duplicateDelivery = WhatsAppNotificationListener.notificationDedupeDigest(
            "whatsapp|conversation", 1000L, "700000000", "500"
        )
        assertTrue(first != repeated)
        assertEquals(first, duplicateDelivery)
    }
}
