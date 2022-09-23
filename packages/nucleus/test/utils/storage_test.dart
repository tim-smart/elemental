import 'package:nucleus/nucleus.dart';
import 'package:test/test.dart';

void main() {
  group('stateAtomWithStorage', () {
    test('it reads and writes to the storage', () {
      final NucleusStorage storage = MemoryNucleusStorage();
      final storageAtom = atom((get) => storage);

      final counter = stateAtomWithStorage(
        0,
        key: 'counter',
        storage: storageAtom,
        fromJson: (i) => i,
        toJson: (i) => i,
      );

      final store = AtomRegistry();

      expect(store.get(counter), 0);
      store.set(counter, 1);
      expect(store.get(counter), 1);
      expect(storage.get('counter'), 1);

      final newAtomRegistry = AtomRegistry();
      expect(newAtomRegistry.get(counter), 1);
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

      final store = AtomRegistry();
      expect(store.get(counter), 0);

      await Future.microtask(() {});

      final newAtomRegistry = AtomRegistry();
      expect(newAtomRegistry.get(counter), 1);
    });
  });
}
