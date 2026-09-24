import { describe, it, expect } from '@ohos/hypium';
import { MetroHotClient, MetroHotMessage } from '../main/ets/metro/MetroHotClient';

export default function metroHotMessageTest() {
  describe('MetroHotMessage', () => {
    it('parses_update_frames_with_revision', () => {
      const msg = MetroHotMessage.parse(
        '{"type":"update-done","body":{"revisionId":"r42"}}'
      );
      expect(msg !== null).assertTrue();
      if (msg !== null) {
        expect(msg.type).assertEqual('update-done');
        expect(msg.revisionId).assertEqual('r42');
      }
    });

    it('parses_error_frames_with_body_fields', () => {
      const msg = MetroHotMessage.parse(
        '{"type":"error","body":{"type":"TransformError","description":"Unexpected token in App.js"}}'
      );
      expect(msg !== null).assertTrue();
      if (msg !== null) {
        expect(msg.errorType).assertEqual('TransformError');
        expect(msg.description).assertEqual('Unexpected token in App.js');
      }
    });

    it('rejects_non_json_and_typeless_frames', () => {
      expect(MetroHotMessage.parse('not json at all')).assertNull();
      expect(MetroHotMessage.parse('{"foo":1}')).assertNull();
      expect(MetroHotMessage.parse('{"type":42}')).assertNull();
    });

    it('parses_bodyless_frames', () => {
      const msg = MetroHotMessage.parse('{"type":"update-start"}');
      expect(msg !== null).assertTrue();
      if (msg !== null) {
        expect(msg.type).assertEqual('update-start');
        expect(msg.description).assertEqual('');
      }
    });
  });

  describe('MetroHotClient.hotUrlFor', () => {
    it('maps_http_to_ws_and_https_to_wss', () => {
      expect(MetroHotClient.hotUrlFor('http://192.168.1.10:8081'))
        .assertEqual('ws://192.168.1.10:8081/hot');
      expect(MetroHotClient.hotUrlFor('https://tunnel.example.com'))
        .assertEqual('wss://tunnel.example.com/hot');
    });

    it('strips_paths_from_project_url', () => {
      expect(MetroHotClient.hotUrlFor('http://host:8081/@user/app'))
        .assertEqual('ws://host:8081/hot');
    });

    it('returns_null_for_non_http_urls', () => {
      expect(MetroHotClient.hotUrlFor('exp://host:8081')).assertNull();
    });
  });

  describe('MetroHotClient.frameAction', () => {
    it('maps_reload_frames_and_dev_commands', () => {
      const plain = MetroHotMessage.parse('{"type":"reload"}');
      const cmd = MetroHotMessage.parse(
        '{"type":"send-dev-command","body":{"name":"reload"}}');
      const menu = MetroHotMessage.parse('{"type":"devMenu","body":{"title":"d"}}');
      expect(plain === null).assertFalse();
      expect(cmd === null).assertFalse();
      expect(menu === null).assertFalse();
      if (plain !== null && cmd !== null && menu !== null) {
        expect(MetroHotClient.frameAction(plain)).assertEqual('reload');
        expect(MetroHotClient.frameAction(cmd)).assertEqual('reload');
        expect(MetroHotClient.frameAction(menu)).assertEqual('devMenu');
      }
    });

    it('ignores_other_dev_commands', () => {
      const msg = MetroHotMessage.parse(
        '{"type":"send-dev-command","body":{"name":"toggleInspector"}}');
      expect(msg === null).assertFalse();
      if (msg !== null) {
        expect(MetroHotClient.frameAction(msg)).assertEqual('other');
      }
    });

    it('maps_update_and_error_frames', () => {
      const upd = MetroHotMessage.parse('{"type":"update"}');
      const done = MetroHotMessage.parse('{"type":"update-done"}');
      const err = MetroHotMessage.parse('{"type":"error"}');
      expect(upd === null).assertFalse();
      expect(done === null).assertFalse();
      expect(err === null).assertFalse();
      if (upd !== null && done !== null && err !== null) {
        expect(MetroHotClient.frameAction(upd)).assertEqual('updateStart');
        expect(MetroHotClient.frameAction(done)).assertEqual('updateDone');
        expect(MetroHotClient.frameAction(err)).assertEqual('error');
      }
    });
  });
}
