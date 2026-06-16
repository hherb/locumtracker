package com.hherb.locumtracker.core.util

import kotlin.random.Random

/**
 * Number of random bytes in a UUID (128 bits).
 */
private const val UUID_BYTE_COUNT = 16

/**
 * Generates a random RFC 4122 version-4 UUID rendered as a canonical
 * `8-4-4-4-12` lowercase hexadecimal string.
 *
 * This is a pure Kotlin implementation so it can be used from `commonMain`
 * across all Kotlin Multiplatform targets without depending on the
 * experimental `kotlin.uuid` API (which requires Kotlin 2.0+) or on
 * platform-specific UUID types.
 *
 * @return a newly generated version-4 UUID string, e.g. `"1b4e28ba-2fa1-4d8f-bb3a-0c2e9f7a1c3d"`.
 */
fun randomUuidString(): String {
    val bytes = Random.nextBytes(UUID_BYTE_COUNT)
    // Set the version (4) and variant (RFC 4122) bits per the UUID spec.
    bytes[6] = ((bytes[6].toInt() and 0x0F) or 0x40).toByte()
    bytes[8] = ((bytes[8].toInt() and 0x3F) or 0x80).toByte()

    val hex = bytes.joinToString("") { byte ->
        ((byte.toInt() and 0xFF) + 0x100).toString(16).substring(1)
    }
    return buildString {
        append(hex, 0, 8)
        append('-')
        append(hex, 8, 12)
        append('-')
        append(hex, 12, 16)
        append('-')
        append(hex, 16, 20)
        append('-')
        append(hex, 20, 32)
    }
}
