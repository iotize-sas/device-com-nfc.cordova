/*******************************************************************************
 *   ______
 *  / _____) /|
 * | |      / /
 * | | /\  / /
 * | | \ \/ /  _      Copyright (c) KEOLABS, 2014
 * | |  \__/  | |        http://www.keolabs.com
 * | |________| |
 *  \__________/
 *
 ********************************************************************************
 *@file          : KeoComProtNFC.java
 *@author        : Yves Ragot
 *@version       : $Id: KeoComProtNFC.java 6072 2017-12-13 15:37:21Z yves.ragot $
 *@brief         : Management of NFC protocol in the Keolink project.
 *
 *******************************************************************************/
package com.chariotsolutions.nfc.plugin;

import android.nfc.Tag;

import java.util.Arrays;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.iotize.android.communication.client.impl.protocol.AbstractComProtocol;

public abstract class NFCProtocol extends AbstractComProtocol {

    private static final String TAG = "NFCProtocol";

    /**
     * AID for LwM2M application.
     * <p>
     * This frame must be send first
     * It is useful when Nfc pairing mandatory option is set on device.
     */
    public static final byte[] LWM2M_CARD_AID_BYTES = new byte[]{
            (byte) 0x00, // CLA
            (byte) 0xA4, // INS
            (byte) 0x04, // P1
            (byte) 0x00, // P2
            (byte) 0x07, // LC
            // DATA
            (byte) 0xF0,
            (byte) 0x02,
            (byte) 0x4C,
            (byte) 0x77,
            (byte) 0x4D,
            (byte) 0x32,
            (byte) 0x4D,
            // --
            (byte) 0x90, // SW1
            (byte) 0x00, // SW2

    };

    @NonNull
    private final Tag mTag;

    public NFCProtocol(@NonNull Tag tag) {
        this.mTag = tag;
    }

    public static NFCProtocol create(@NonNull Tag tag) {
        // Create instance NFC protocol
        NFCProtocol protocol;
        switch (getNFCVersion(tag)) {
            case 4:
                protocol = new NFC4Protocol(tag);
                break;
            case 5:
            default:
                protocol = new NFC5Protocol(tag);
        }

        return protocol;
    }

    public static int getNFCVersion(@NonNull Tag nfcTag) {
        byte[] tagId = nfcTag.getId();
        boolean isNfcV = (tagId.length == 8);
        if (isNfcV) {
            return 5;
        } else {
            return 4;
        }
    }

    public boolean isSameTag(@Nullable Tag tag) {
        if (tag == null) {
            return false;
        }
        return Arrays.equals(tag.getId(), mTag.getId());
    }

    @NonNull
    public Tag getTag() {
        return mTag;
    }

}

