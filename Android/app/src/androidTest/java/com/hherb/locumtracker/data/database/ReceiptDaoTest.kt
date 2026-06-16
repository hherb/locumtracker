package com.hherb.locumtracker.data.database

import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hherb.locumtracker.data.database.dao.ReceiptDao
import com.hherb.locumtracker.data.database.entity.AttachmentEntity
import com.hherb.locumtracker.data.database.entity.ReceiptEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ReceiptDaoTest {

    private lateinit var database: LocumTrackerDatabase
    private lateinit var receiptDao: ReceiptDao

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        database = Room.inMemoryDatabaseBuilder(context, LocumTrackerDatabase::class.java)
            .build()
        receiptDao = database.receiptDao()
    }

    @After
    fun teardown() {
        database.close()
    }

    @Test
    fun testInsertAndGetReceipt() = runTest {
        val receipt = ReceiptEntity(
            id = "receipt-1",
            dailyRecordId = null,
            assignmentId = "assign-1",
            amount = 150.0,
            category = "travel",
            date = System.currentTimeMillis(),
            receiptDescription = "Fuel",
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )

        receiptDao.insertReceipt(receipt)

        val retrieved = receiptDao.getReceiptById("receipt-1")
        assertNotNull(retrieved)
        assertEquals(150.0, retrieved?.amount)
        assertEquals("travel", retrieved?.category)
    }

    @Test
    fun testGetAllReceipts() = runTest {
        val receipt1 = createReceipt("1", 100.0)
        val receipt2 = createReceipt("2", 200.0)

        receiptDao.insertReceipt(receipt1)
        receiptDao.insertReceipt(receipt2)

        val receipts = receiptDao.getAllReceipts().first()
        assertEquals(2, receipts.size)
    }

    @Test
    fun testGetReceiptsByCategory() = runTest {
        val receipt1 = createReceipt("1", 100.0, category = "travel")
        val receipt2 = createReceipt("2", 200.0, category = "meals")
        val receipt3 = createReceipt("3", 150.0, category = "travel")

        receiptDao.insertReceipt(receipt1)
        receiptDao.insertReceipt(receipt2)
        receiptDao.insertReceipt(receipt3)

        val travelReceipts = receiptDao.getReceiptsByCategory("travel").first()
        assertEquals(2, travelReceipts.size)
    }

    @Test
    fun testGetTotalExpenses() = runTest {
        val receipt1 = createReceipt("1", 100.0)
        val receipt2 = createReceipt("2", 200.0)

        receiptDao.insertReceipt(receipt1)
        receiptDao.insertReceipt(receipt2)

        val total = receiptDao.getTotalExpenses().first()
        assertEquals(300.0, total)
    }

    @Test
    fun testUpdateReceipt() = runTest {
        val receipt = createReceipt("1", 100.0)
        receiptDao.insertReceipt(receipt)

        val updated = receipt.copy(amount = 150.0, receiptDescription = "Updated")
        receiptDao.updateReceipt(updated)

        val retrieved = receiptDao.getReceiptById("1")
        assertEquals(150.0, retrieved?.amount)
        assertEquals("Updated", retrieved?.receiptDescription)
    }

    @Test
    fun testDeleteReceipt() = runTest {
        val receipt = createReceipt("1", 100.0)
        receiptDao.insertReceipt(receipt)

        receiptDao.deleteReceipt(receipt)

        val retrieved = receiptDao.getReceiptById("1")
        assertNull(retrieved)
    }

    @Test
    fun testInsertAndGetAttachment() = runTest {
        val attachment = AttachmentEntity(
            id = "attachment-1",
            receiptId = "receipt-1",
            assignmentId = null,
            filename = "receipt.jpg",
            fileType = "image/jpeg",
            fileSize = 1024,
            fileData = ByteArray(100),
            notes = null,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )

        receiptDao.insertAttachment(attachment)

        val retrieved = receiptDao.getAttachmentById("attachment-1")
        assertNotNull(retrieved)
        assertEquals("receipt.jpg", retrieved?.filename)
    }

    @Test
    fun testGetAttachmentsForReceipt() = runTest {
        val attachment1 = createAttachment("1", "receipt-1")
        val attachment2 = createAttachment("2", "receipt-1")
        val attachment3 = createAttachment("3", "receipt-2")

        receiptDao.insertAttachment(attachment1)
        receiptDao.insertAttachment(attachment2)
        receiptDao.insertAttachment(attachment3)

        val attachments = receiptDao.getAttachmentsForReceipt("receipt-1").first()
        assertEquals(2, attachments.size)
    }

    @Test
    fun testDeleteAttachmentsForReceipt() = runTest {
        val attachment1 = createAttachment("1", "receipt-1")
        val attachment2 = createAttachment("2", "receipt-1")
        val attachment3 = createAttachment("3", "receipt-2")

        receiptDao.insertAttachment(attachment1)
        receiptDao.insertAttachment(attachment2)
        receiptDao.insertAttachment(attachment3)

        receiptDao.deleteAttachmentsForReceipt("receipt-1")

        val attachments = receiptDao.getAttachmentsForReceipt("receipt-1").first()
        assertTrue(attachments.isEmpty())

        // Receipt 2's attachment should still exist
        val attachment2Retrieved = receiptDao.getAttachmentById("3")
        assertNotNull(attachment2Retrieved)
    }

    private fun createReceipt(
        id: String,
        amount: Double,
        category: String = "other"
    ): ReceiptEntity {
        return ReceiptEntity(
            id = id,
            dailyRecordId = null,
            assignmentId = null,
            amount = amount,
            category = category,
            date = System.currentTimeMillis(),
            receiptDescription = "Test receipt",
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
    }

    private fun createAttachment(
        id: String,
        receiptId: String
    ): AttachmentEntity {
        return AttachmentEntity(
            id = id,
            receiptId = receiptId,
            assignmentId = null,
            filename = "test.jpg",
            fileType = "image/jpeg",
            fileSize = 1024,
            fileData = null,
            notes = null,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
    }
}
