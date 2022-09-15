import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

void main() {
  group('atomWithStorage', () {
    test('it reads and writes to the storage', () {
      final storage = MemoryNucleusStorage();
      final storageAtom = atom((get) => storage);

      final counter = stateAtomWithStorage(
        0,
        key: 'counter',
        storage: storageAtom,
        fromJson: (i) => i,
        toJson: (i) => i,
      );

      final store = Store();

      expect(store.read(counter), 0);
      store.put(counter, 1);
      expect(store.read(counter), 1);
      expect(storage.get('counter'), 1);

      final newStore = Store();
      expect(newStore.read(counter), 1);
    });
  });

  group('atomWithStorage', () {
    test('it reads and writes to the storage', () async {
      final storage = MemoryNucleusStorage();
      final storageAtom = atom((get) => storage);

      final counter = atomWithStorage<int, int>(
        (get, read, write) {
          Future.microtask(() {
            write(1);
          });
          return read() ?? 0;
        },
        key: 'counter',
        storage: storageAtom,
        fromJson: (i) => i,
        toJson: (i) => i,
      );

      final store = Store();
      expect(store.read(counter), 0);

      await Future.microtask(() {});

      final newStore = Store();
      expect(newStore.read(counter), 1);
    });
  });
}
